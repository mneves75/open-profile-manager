import Darwin
import Foundation
import ProfileCore
import Synchronization
import Testing

@testable import OpenProfileManager

@MainActor
@Suite("Native app model")
struct AppModelTests {
  @Test("A superseded reload finishing first leaves the newer reload in charge")
  func supersededReloadFinishingFirst() async throws {
    let fixture = try await OverlappingReloads()
    defer { fixture.cleanUp() }

    fixture.reads.complete(0)
    await fixture.staleReload.value
    #expect(fixture.model.isRefreshing)

    fixture.reads.complete(1)
    await fixture.currentReload.value
    #expect(!fixture.model.isRefreshing)
    #expect(fixture.model.profiles.map(\.id.rawValue) == ["alpha", "beta"])
    #expect(Set(fixture.model.statuses.keys.map(\.rawValue)) == ["alpha", "beta"])
  }

  @Test("A superseded reload finishing last cannot overwrite newer statuses")
  func supersededReloadFinishingLast() async throws {
    let fixture = try await OverlappingReloads()
    defer { fixture.cleanUp() }

    fixture.reads.complete(1)
    await fixture.currentReload.value
    fixture.reads.complete(0)
    await fixture.staleReload.value

    #expect(!fixture.model.isRefreshing)
    #expect(Set(fixture.model.statuses.keys.map(\.rawValue)) == ["alpha", "beta"])
  }
}

/// Starts a reload for profile "alpha", adds "beta", then starts a second reload; both status reads
/// stay pending until the test completes them in the order under test.
@MainActor
private struct OverlappingReloads {
  let root: URL
  let reads = PendingStatusReads()
  let model: AppModel
  let staleReload: Task<Void, Never>
  let currentReload: Task<Void, Never>

  init() async throws {
    root = try Self.privateTemporaryDirectory()
    let manager = try ProfileManager(
      registryURL: root.appendingPathComponent("registry/profiles.json"),
      applicationSupportDirectory: root.appendingPathComponent("registry", isDirectory: true)
    )
    _ = try manager.addProfile(
      id: "alpha",
      displayName: "Alpha",
      codexHome: root.appendingPathComponent("alpha-home", isDirectory: true)
    )
    let reads = reads
    let model = AppModel(manager: manager) { _, profiles in
      await reads.read(profiles)
    }
    self.model = model

    staleReload = Task { await model.reload() }
    try await reads.waitForReads(1)
    _ = try manager.addProfile(
      id: "beta",
      displayName: "Beta",
      codexHome: root.appendingPathComponent("beta-home", isDirectory: true)
    )
    currentReload = Task { await model.reload() }
    try await reads.waitForReads(2)
  }

  func cleanUp() {
    try? FileManager.default.removeItem(at: root)
  }

  private static func privateTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("AppModelTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    guard chmod(url.path, S_IRWXU) == 0 else {
      throw CocoaError(.fileWriteNoPermission)
    }
    return url
  }
}

/// Holds each status read open until the test completes it, so reload ordering is deterministic.
private final class PendingStatusReads: Sendable {
  private typealias Read = (
    profiles: [Profile], continuation: CheckedContinuation<[ProfileStatus], Never>
  )
  private let pending = Mutex<[Read]>([])

  func read(_ profiles: [Profile]) async -> [ProfileStatus] {
    await withCheckedContinuation { continuation in
      pending.withLock { $0.append((profiles, continuation)) }
    }
  }

  func waitForReads(_ count: Int) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while pending.withLock({ $0.count }) < count {
      guard ContinuousClock.now < deadline else { throw CancellationError() }
      try await Task.sleep(for: .milliseconds(5))
    }
  }

  func complete(_ index: Int) {
    let read = pending.withLock { $0[index] }
    read.continuation.resume(
      returning: read.profiles.map {
        ProfileStatus(profileID: $0.id, displayName: $0.displayName, state: .available)
      })
  }
}
