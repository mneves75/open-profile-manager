import ProfileCore
import Testing

@testable import OpenProfileManager

@Test func profileCoreErrorLocalizationPreservesValues() {
  let message = L10n.error(
    ProfileCoreError.profileDirectoryAlreadyUsed(
      path: "/Users/example/.codex",
      profileID: "work"
    )
  )

  #expect(message.contains("/Users/example/.codex"))
  #expect(message.contains("work"))
}

@Test func profileCoreErrorLocalizationPreservesNumericValues() {
  #expect(L10n.error(ProfileCoreError.unsupportedRegistryVersion(42)).contains("42"))
}
