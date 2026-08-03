import Foundation

enum ProfileEnvironment {
  private static let conflictingOverrides = [
    "CODEX_ACCESS_TOKEN",
    "CODEX_API_KEY",
    "CODEX_SQLITE_HOME",
    "OPENAI_API_KEY",
  ]

  static func isolated(
    from environment: [String: String],
    codexHome: URL
  ) -> [String: String] {
    var isolatedEnvironment = environment
    for key in conflictingOverrides {
      isolatedEnvironment.removeValue(forKey: key)
    }
    isolatedEnvironment["CODEX_HOME"] = codexHome.path
    return isolatedEnvironment
  }
}
