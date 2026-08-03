import Darwin
import Foundation

public enum ProfileStatusState: String, Codable, Sendable {
  case available
  case notAuthenticated = "not_authenticated"
  case unavailable
}

public struct AccountSummary: Codable, Equatable, Sendable {
  public let type: String
  public let email: String?
  public let planType: String?

  public init(type: String, email: String? = nil, planType: String? = nil) {
    self.type = type
    self.email = email
    self.planType = planType
  }
}

public struct RateLimitWindow: Codable, Equatable, Sendable {
  public let usedPercent: Int
  public let resetsAt: Int64?
  public let windowDurationMinutes: Int64?

  public init(usedPercent: Int, resetsAt: Int64?, windowDurationMinutes: Int64?) {
    self.usedPercent = usedPercent
    self.resetsAt = resetsAt
    self.windowDurationMinutes = windowDurationMinutes
  }
}

public struct RateLimitSummary: Codable, Equatable, Sendable {
  public let planType: String?
  public let primary: RateLimitWindow?
  public let secondary: RateLimitWindow?
  public let hasCredits: Bool?
  public let unlimitedCredits: Bool?

  public init(
    planType: String?,
    primary: RateLimitWindow?,
    secondary: RateLimitWindow?,
    hasCredits: Bool?,
    unlimitedCredits: Bool?
  ) {
    self.planType = planType
    self.primary = primary
    self.secondary = secondary
    self.hasCredits = hasCredits
    self.unlimitedCredits = unlimitedCredits
  }
}

public struct ProfileStatus: Codable, Equatable, Sendable {
  public let profileID: ProfileID
  public let displayName: String
  public let state: ProfileStatusState
  public let account: AccountSummary?
  public let rateLimits: RateLimitSummary?
  public let message: String?

  public init(
    profileID: ProfileID,
    displayName: String,
    state: ProfileStatusState,
    account: AccountSummary? = nil,
    rateLimits: RateLimitSummary? = nil,
    message: String? = nil
  ) {
    self.profileID = profileID
    self.displayName = displayName
    self.state = state
    self.account = account
    self.rateLimits = rateLimits
    self.message = message
  }
}

public struct CodexStatusService: Sendable {
  public let timeout: TimeInterval
  public let outputLimit: Int

  public init(timeout: TimeInterval = 5, outputLimit: Int = 1_048_576) {
    self.timeout = max(0.1, timeout)
    self.outputLimit = max(1_024, outputLimit)
  }

  public func readStatus(
    for profile: Profile,
    codexExecutable: URL? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> ProfileStatus {
    do {
      try PrivateDirectory.validate(profile.codexHome, operation: "use CODEX_HOME")
    } catch {
      return unavailable(profile, "CODEX_HOME is not a private, current-user-owned directory.")
    }

    let executable: URL
    do {
      if let codexExecutable {
        let normalized = try Profile.normalizedAbsoluteURL(
          codexExecutable,
          field: "Codex executable"
        )
        guard FileManager.default.isExecutableFile(atPath: normalized.path) else {
          return unavailable(profile, "The Codex executable is not available.")
        }
        executable = normalized
      } else {
        executable = try ExecutableLocator.resolve("codex", environment: environment)
      }
    } catch {
      return unavailable(profile, "Codex CLI was not found on PATH.")
    }

    let process = Process()
    let standardInput = Pipe()
    let standardOutput = Pipe()
    let standardError = Pipe()
    let collector = BoundedJSONLCollector(limit: outputLimit)
    process.executableURL = executable
    process.arguments = ["app-server"]
    process.environment = ProfileEnvironment.isolated(
      from: environment,
      codexHome: profile.codexHome
    )
    process.standardInput = standardInput
    process.standardOutput = standardOutput
    process.standardError = standardError

    standardOutput.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      if data.isEmpty {
        collector.finish()
      } else {
        collector.append(data)
      }
    }
    standardError.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      if !data.isEmpty {
        collector.discard(count: data.count)
      }
    }

    do {
      try process.run()
    } catch {
      standardOutput.fileHandleForReading.readabilityHandler = nil
      standardError.fileHandleForReading.readabilityHandler = nil
      return unavailable(profile, "Codex app-server could not be started.")
    }

    defer {
      try? standardInput.fileHandleForWriting.close()
      stop(process)
      standardOutput.fileHandleForReading.readabilityHandler = nil
      standardError.fileHandleForReading.readabilityHandler = nil
      try? standardOutput.fileHandleForReading.close()
      try? standardError.fileHandleForReading.close()
    }

    let deadline = Date().addingTimeInterval(timeout)
    guard Self.writeSafely(Self.initializeRequest, to: standardInput.fileHandleForWriting),
      collector.waitForResponse(id: 1, until: deadline),
      !collector.exceededLimit,
      !collector.responseHasError(id: 1)
    else {
      return unavailable(
        profile,
        collector.exceededLimit
          ? "Codex app-server exceeded the status output limit."
          : "Codex app-server did not initialize in time.")
    }

    guard Self.writeSafely(Self.statusRequests, to: standardInput.fileHandleForWriting) else {
      return unavailable(profile, "Codex app-server stopped before status was available.")
    }
    // app-server treats stdin EOF as shutdown and may stop before draining already-buffered requests.
    // Keep the transport open until the responses arrive; the defer above closes it during cleanup.

    guard collector.waitForResponse(id: 2, until: deadline), !collector.exceededLimit else {
      return unavailable(
        profile,
        collector.exceededLimit
          ? "Codex app-server exceeded the status output limit."
          : "Codex account status timed out.")
    }
    _ = collector.waitForResponse(id: 3, until: deadline)
    guard !collector.exceededLimit else {
      return unavailable(profile, "Codex app-server exceeded the status output limit.")
    }
    return Self.parseStatus(profile: profile, messages: collector.snapshot())
  }

  public static func parseStatus(profile: Profile, messages: [Data]) -> ProfileStatus {
    guard let accountObject = responseResult(id: 2, messages: messages) else {
      return ProfileStatus(
        profileID: profile.id,
        displayName: profile.displayName,
        state: .unavailable,
        message: "Codex account status is unavailable."
      )
    }

    let requiresAuthentication = accountObject["requiresOpenaiAuth"] as? Bool ?? true
    let rateLimitSummary = responseResult(id: 3, messages: messages)
      .flatMap { $0["rateLimits"] as? [String: Any] }
      .map(parseRateLimits)
    guard let account = accountObject["account"] as? [String: Any] else {
      return ProfileStatus(
        profileID: profile.id,
        displayName: profile.displayName,
        state: requiresAuthentication ? .notAuthenticated : .available,
        rateLimits: rateLimitSummary,
        message: requiresAuthentication
          ? "Run 'opm login \(profile.id.rawValue)' to authenticate this profile."
          : (rateLimitSummary == nil ? "This profile does not require OpenAI authentication." : nil)
      )
    }

    let accountSummary = AccountSummary(
      type: boundedString(account["type"], maximumBytes: 64) ?? "unknown",
      email: boundedString(account["email"], maximumBytes: 320),
      planType: boundedString(account["planType"], maximumBytes: 64)
    )
    return ProfileStatus(
      profileID: profile.id,
      displayName: profile.displayName,
      state: .available,
      account: accountSummary,
      rateLimits: rateLimitSummary,
      message: rateLimitSummary == nil ? "Rate-limit status is unavailable." : nil
    )
  }

  private static let initializeRequest = Data(
    "{\"id\":1,\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"open-profile-manager\",\"title\":\"Open Profile Manager\",\"version\":\"\(OPMVersion.current)\"}}}\n"
      .utf8
  )

  private static let statusRequests = Data(
    "{\"method\":\"initialized\"}\n{\"id\":2,\"method\":\"account/read\",\"params\":{\"refreshToken\":false}}\n{\"id\":3,\"method\":\"account/rateLimits/read\",\"params\":null}\n"
      .utf8
  )

  private func unavailable(_ profile: Profile, _ message: String) -> ProfileStatus {
    ProfileStatus(
      profileID: profile.id,
      displayName: profile.displayName,
      state: .unavailable,
      message: message
    )
  }

  static func writeSafely(_ data: Data, to handle: FileHandle) -> Bool {
    guard fcntl(handle.fileDescriptor, F_SETNOSIGPIPE, 1) == 0 else {
      return false
    }
    do {
      try handle.write(contentsOf: data)
      return true
    } catch {
      return false
    }
  }

  private func stop(_ process: Process) {
    guard process.isRunning else { return }
    process.terminate()
    usleep(100_000)
    if process.isRunning {
      _ = kill(process.processIdentifier, SIGKILL)
    }
    process.waitUntilExit()
  }

  private static func responseResult(id: Int, messages: [Data]) -> [String: Any]? {
    for message in messages {
      guard let object = try? JSONSerialization.jsonObject(with: message) as? [String: Any],
        (object["id"] as? Int) == id,
        object["error"] == nil,
        let result = object["result"] as? [String: Any]
      else {
        continue
      }
      return result
    }
    return nil
  }

  private static func parseRateLimits(_ object: [String: Any]) -> RateLimitSummary {
    let credits = object["credits"] as? [String: Any]
    return RateLimitSummary(
      planType: boundedString(object["planType"], maximumBytes: 64),
      primary: parseWindow(object["primary"] as? [String: Any]),
      secondary: parseWindow(object["secondary"] as? [String: Any]),
      hasCredits: credits?["hasCredits"] as? Bool,
      unlimitedCredits: credits?["unlimited"] as? Bool
    )
  }

  private static func parseWindow(_ object: [String: Any]?) -> RateLimitWindow? {
    guard let object,
      let usedPercent = object["usedPercent"] as? Int,
      (0...100).contains(usedPercent)
    else { return nil }
    return RateLimitWindow(
      usedPercent: usedPercent,
      resetsAt: integer(object["resetsAt"]),
      windowDurationMinutes: integer(object["windowDurationMins"])
    )
  }

  private static func integer(_ value: Any?) -> Int64? {
    (value as? NSNumber)?.int64Value
  }

  private static func boundedString(_ value: Any?, maximumBytes: Int) -> String? {
    guard let string = value as? String,
      !string.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
      string.utf8.count <= maximumBytes
    else {
      return nil
    }
    return string
  }
}

private final class BoundedJSONLCollector: @unchecked Sendable {
  private static let maximumRecordCount = 256
  private let condition = NSCondition()
  private let limit: Int
  private var totalCount = 0
  private var buffer = Data()
  private var lines: [Data] = []
  private var isFinished = false
  private var didExceedLimit = false

  init(limit: Int) {
    self.limit = limit
  }

  var exceededLimit: Bool {
    condition.withLock { didExceedLimit }
  }

  func append(_ data: Data) {
    condition.withLock {
      guard !didExceedLimit else { return }
      totalCount += data.count
      guard totalCount <= limit else {
        didExceedLimit = true
        buffer.removeAll(keepingCapacity: false)
        condition.broadcast()
        return
      }
      buffer.append(data)
      while let newline = buffer.firstIndex(of: 0x0A) {
        let line = Data(buffer[..<newline])
        buffer.removeSubrange(...newline)
        if !line.isEmpty {
          guard lines.count < Self.maximumRecordCount else {
            didExceedLimit = true
            buffer.removeAll(keepingCapacity: false)
            condition.broadcast()
            return
          }
          lines.append(line)
        }
      }
      condition.broadcast()
    }
  }

  func discard(count: Int) {
    condition.withLock {
      totalCount += count
      if totalCount > limit {
        didExceedLimit = true
        condition.broadcast()
      }
    }
  }

  func finish() {
    condition.withLock {
      if !buffer.isEmpty {
        lines.append(buffer)
        buffer.removeAll(keepingCapacity: false)
      }
      isFinished = true
      condition.broadcast()
    }
  }

  func waitForResponse(id: Int, until deadline: Date) -> Bool {
    condition.lock()
    defer { condition.unlock() }
    while !containsResponse(id: id), !didExceedLimit, !isFinished {
      guard condition.wait(until: deadline) else { break }
    }
    return containsResponse(id: id)
  }

  func responseHasError(id: Int) -> Bool {
    condition.withLock {
      lines.contains { line in
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
          (object["id"] as? Int) == id
        else {
          return false
        }
        return object["error"] != nil
      }
    }
  }

  func snapshot() -> [Data] {
    condition.withLock { lines }
  }

  private func containsResponse(id: Int) -> Bool {
    lines.contains { line in
      guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
        return false
      }
      return (object["id"] as? Int) == id
    }
  }
}

extension NSCondition {
  fileprivate func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try body()
  }
}
