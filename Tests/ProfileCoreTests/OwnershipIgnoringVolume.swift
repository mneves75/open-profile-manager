import Foundation

/// A disposable APFS disk image attached with ownership ignored (`noowners`), which needs no root.
struct OwnershipIgnoringVolume {
  let mountPoint: URL

  init(in directory: URL) throws {
    let image = directory.appendingPathComponent("volume.dmg")
    mountPoint = directory.appendingPathComponent("volume", isDirectory: true)
    try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: false)
    try Self.hdiutil([
      "create", "-quiet", "-size", "8m", "-fs", "APFS", "-volname", "OPMTest", image.path,
    ])
    try Self.hdiutil([
      "attach", "-quiet", "-nobrowse", "-owners", "off", "-mountpoint", mountPoint.path, image.path,
    ])
  }

  func detach() {
    try? Self.hdiutil(["detach", "-quiet", "-force", mountPoint.path])
  }

  private static func hdiutil(_ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw CocoaError(.fileWriteUnknown)
    }
  }
}
