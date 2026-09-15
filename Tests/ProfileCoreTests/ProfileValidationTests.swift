import Darwin
import Foundation
import Testing

@testable import ProfileCore

@Suite("Profile validation")
struct ProfileValidationTests {
  @Test("Profile IDs accept only the documented grammar")
  func profileIDGrammar() throws {
    for valid in ["a", "profile-1", "profile_one", String(repeating: "a", count: 32)] {
      #expect(try ProfileID(valid).rawValue == valid)
    }
    for invalid in [
      "", "UPPER", "-leading", "_leading", "has space", "a.b", String(repeating: "a", count: 33),
    ] {
      #expect(throws: ProfileCoreError.self) {
        try ProfileID(invalid)
      }
    }
  }

  @Test("Profile names are trimmed and cannot be blank")
  func displayNameValidation() throws {
    let profile = try Profile(
      id: ProfileID("work"),
      displayName: "  Work Profile  ",
      codexHome: URL(fileURLWithPath: "/tmp/opm-work")
    )
    #expect(profile.displayName == "Work Profile")
    #expect(throws: ProfileCoreError.self) {
      try Profile(
        id: ProfileID("blank"),
        displayName: " \n ",
        codexHome: URL(fileURLWithPath: "/tmp/opm-blank")
      )
    }
    for invalid in [
      "line\nbreak",
      "escape\u{1B}sequence",
      String(repeating: "n", count: Profile.maximumDisplayNameBytes + 1),
    ] {
      #expect(throws: ProfileCoreError.invalidDisplayName) {
        try Profile(
          id: ProfileID("invalid-name"),
          displayName: invalid,
          codexHome: URL(fileURLWithPath: "/tmp/opm-invalid-name")
        )
      }
    }
  }

  @Test("Profile paths are standardized")
  func pathStandardization() throws {
    let profile = try Profile(
      id: ProfileID("standard"),
      displayName: "Standard",
      codexHome: URL(fileURLWithPath: "/tmp/one/../two")
    )
    #expect(profile.codexHome.path == "/tmp/two")
    for invalidPath in [
      "/",
      "/Users/..",
      "/tmp/control\u{1B}path",
      // One byte over the limit, and far beyond PATH_MAX where macOS 15 truncates standardized paths.
      "/" + String(repeating: "p", count: Profile.maximumPathBytes),
      "/" + String(repeating: "p", count: 4_096),
    ] {
      let url = URL(fileURLWithPath: invalidPath)
      #expect(
        throws: ProfileCoreError.self,
        "input \(invalidPath.utf8.count) bytes; standardized \(url.standardizedFileURL.path.utf8.count)"
      ) {
        try Profile(
          id: ProfileID("unsafe-path"),
          displayName: "Unsafe path",
          codexHome: url
        )
      }
    }
  }

  @Test("Paths at the byte limit are kept whole")
  func pathAtLimitIsNotTruncated() throws {
    let path = "/" + String(repeating: "p", count: Profile.maximumPathBytes - 1)
    let profile = try Profile(
      id: ProfileID("long-path"),
      displayName: "Long path",
      codexHome: URL(fileURLWithPath: path)
    )
    #expect(profile.codexHome.path == path)
  }

  @Test("User-entered paths reject relative values before URL rebasing")
  func userEnteredPaths() throws {
    #expect(throws: ProfileCoreError.invalidAbsolutePath(field: .codexHome, path: "profile-home")) {
      try Profile.fileURL(fromUserPath: "profile-home", field: .codexHome)
    }

    let expected = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".codex", isDirectory: true)
      .standardizedFileURL
    #expect(try Profile.fileURL(fromUserPath: "~/.codex", field: .codexHome) == expected)

    // NSString tilde expansion truncates at PATH_MAX; with "/" at byte 1,024 the result would be a
    // valid 1,023-byte parent of the entered directory.
    let overLong = "/" + String(repeating: "a", count: Profile.maximumPathBytes - 1) + "/child-dir"
    #expect(throws: ProfileCoreError.self) {
      try Profile.fileURL(fromUserPath: overLong, field: .codexHome)
    }
    #expect(throws: ProfileCoreError.self) {
      try Profile.fileURL(fromUserPath: "~/" + overLong, field: .codexHome)
    }
  }
}
