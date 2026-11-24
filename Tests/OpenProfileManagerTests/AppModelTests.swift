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

  @Test("A newer reload cancels the superseded status read")
  func newerReloadCancelsSupersededRead() async throws {
    let fixture = try await OverlappingReloads()
    defer { fixture.cleanUp() }

    #expect(fixture.reads.wasCancelled(0))
    #expect(!fixture.reads.wasCancelled(1))

    fixture.reads.complete(1)
    await fixture.currentReload.value
    fixture.reads.complete(0)
    await fixture.staleReload.value
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

  @Test(
    "Removing a profile drops stale status, finishes reload, and closes the inspector when empty")
  func removalPrunesStaleStateAndSelection() async throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let manager = try ProfileManager(
      registryURL: root.appendingPathComponent("registry/profiles.json"),
      applicationSupportDirectory: root.appendingPathComponent("registry", isDirectory: true)
    )
    let profile = try manager.addProfile(
      id: "work",
      displayName: "Work",
      codexHome: root.appendingPathComponent("work-home", isDirectory: true)
    )
    let reads = PendingStatusReads()
    let model = AppModel(manager: manager) { _, profiles in
      await reads.read(profiles)
    }

    let initialReload = Task { await model.reload() }
    try await reads.waitForReads(1)
    reads.complete(0)
    await initialReload.value

    model.isInspectorPresented = true
    model.requestRemoval(of: profile)
    model.confirmRemoval()

    try await reads.waitForReads(2)
    reads.complete(1)

    let deadline = ContinuousClock.now + .seconds(5)
    while model.isSaving || model.isRefreshing {
      guard ContinuousClock.now < deadline else { throw CancellationError() }
      try await Task.sleep(for: .milliseconds(5))
    }

    #expect(model.profiles.isEmpty)
    #expect(model.statuses.isEmpty)
    #expect(model.selectedProfileID == nil)
    #expect(!model.isInspectorPresented)
    #expect(!model.isRefreshing)
  }

  @Test("Rapid command copies cancel prior feedback timers deterministically")
  func rapidCommandCopiesCancelPriorTimer() async throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let alpha = try Profile(
      id: ProfileID("alpha"),
      displayName: "Alpha",
      codexHome: root.appendingPathComponent("alpha", isDirectory: true)
    )
    let beta = try Profile(
      id: ProfileID("beta"),
      displayName: "Beta",
      codexHome: root.appendingPathComponent("beta", isDirectory: true)
    )
    var copiedStrings: [String] = []
    let timers = PendingTimers()
    let model = AppModel(
      manager: nil,
      writePasteboard: { value in
        copiedStrings.append(value)
        return true
      },
      sleep: { _ in
        try await timers.wait()
      }
    )

    model.copyCLICommand(for: alpha)
    try await timers.waitForCount(1)
    #expect(model.copiedCommand == .cli(alpha.id))

    model.copyLoginCommand(for: beta)
    try await timers.waitForCount(2)
    #expect(timers.wasCancelled(0))
    #expect(!timers.wasCancelled(1))
    #expect(model.copiedCommand == .login(beta.id))
    #expect(copiedStrings == ["opm run alpha", "opm login beta"])

    timers.resume(0)
    await Task.yield()
    #expect(model.copiedCommand == .login(beta.id))

    timers.resume(1)
    let deadline = ContinuousClock.now + .seconds(5)
    while model.copiedCommand != nil {
      guard ContinuousClock.now < deadline else { throw CancellationError() }
      await Task.yield()
    }
    #expect(model.copiedCommand == nil)
  }

  @Test("Failed pasteboard writes do not show copied feedback")
  func failedPasteboardWriteSkipsFeedback() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let profile = try Profile(
      id: ProfileID("alpha"),
      displayName: "Alpha",
      codexHome: root.appendingPathComponent("alpha", isDirectory: true)
    )
    let model = AppModel(
      manager: nil,
      writePasteboard: { _ in false }
    )
    model.copyCLICommand(for: profile)
    #expect(model.copiedCommand == nil)
  }

  @Test("Profile menu shortcuts are disabled while a modal editor or alert is presented")
  func profileShortcutsDisabledDuringModalState() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let profile = try Profile(
      id: ProfileID("alpha"),
      displayName: "Alpha",
      codexHome: root.appendingPathComponent("alpha", isDirectory: true)
    )
    let model = AppModel(manager: nil)
    model.profiles = [profile]
    model.selectedProfileID = profile.id
    #expect(model.canPerformProfileShortcut)

    model.presentEditor(for: profile)
    #expect(!model.canPerformProfileShortcut)

    model.editor = nil
    model.isShowingRemoveConfirmation = true
    #expect(!model.canPerformProfileShortcut)

    model.isShowingRemoveConfirmation = false
    model.isShowingAlert = true
    #expect(!model.canPerformProfileShortcut)
  }
}

private func privateTemporaryDirectory() throws -> URL {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("AppModelTests-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
  guard chmod(url.path, S_IRWXU) == 0 else {
    throw CocoaError(.fileWriteNoPermission)
  }
  return url
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
    root = try privateTemporaryDirectory()
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
}

/// Holds each status read open until the test completes it, so reload ordering is deterministic.
private final class PendingStatusReads: Sendable {
  private struct Read {
    let id: UUID
    let profiles: [Profile]
    let continuation: CheckedContinuation<[ProfileStatus], Never>
  }

  private struct State {
    var reads: [Read] = []
    var cancelledReadIDs: Set<UUID> = []
  }

  private let state = Mutex(State())

  func read(_ profiles: [Profile]) async -> [ProfileStatus] {
    let id = UUID()
    return await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        state.withLock {
          $0.reads.append(Read(id: id, profiles: profiles, continuation: continuation))
        }
      }
    } onCancel: {
      _ = state.withLock { $0.cancelledReadIDs.insert(id) }
    }
  }

  func waitForReads(_ count: Int) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while state.withLock({ $0.reads.count }) < count {
      guard ContinuousClock.now < deadline else { throw CancellationError() }
      try await Task.sleep(for: .milliseconds(5))
    }
  }

  func wasCancelled(_ index: Int) -> Bool {
    state.withLock { $0.cancelledReadIDs.contains($0.reads[index].id) }
  }

  func complete(_ index: Int) {
    let read = state.withLock { $0.reads[index] }
    read.continuation.resume(
      returning: read.profiles.map {
        ProfileStatus(profileID: $0.id, displayName: $0.displayName, state: .available)
      })
  }
}

/// Holds injected sleep calls open until the test advances them explicitly.
private final class PendingTimers: Sendable {
  private struct Entry {
    let id: UUID
    let continuation: CheckedContinuation<Void, Error>
  }

  private struct State {
    var entries: [Entry] = []
    var cancelledIDs: Set<UUID> = []
  }

  private let state = Mutex(State())

  func wait() async throws {
    let id = UUID()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        state.withLock {
          $0.entries.append(Entry(id: id, continuation: continuation))
        }
      }
    } onCancel: {
      _ = state.withLock { $0.cancelledIDs.insert(id) }
    }
  }

  func waitForCount(_ count: Int) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while state.withLock({ $0.entries.count }) < count {
      guard ContinuousClock.now < deadline else { throw CancellationError() }
      try await Task.sleep(for: .milliseconds(5))
    }
  }

  func wasCancelled(_ index: Int) -> Bool {
    state.withLock { $0.cancelledIDs.contains($0.entries[index].id) }
  }

  func resume(_ index: Int) {
    let entry = state.withLock { $0.entries[index] }
    entry.continuation.resume()
  }
}
