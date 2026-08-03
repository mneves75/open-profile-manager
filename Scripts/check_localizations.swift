#!/usr/bin/env swift
import Foundation

let catalogPath = "Sources/OpenProfileManager/Resources/Localizable.xcstrings"
let sourceDirectory = "Sources/OpenProfileManager"
let requiredLocales = Set(["en-US", "pt-BR"])

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("Localization check failed: \(message)\n".utf8))
  exit(1)
}

func captures(_ pattern: String, in text: String) -> [String] {
  let expression: NSRegularExpression
  do {
    expression = try NSRegularExpression(pattern: pattern)
  } catch {
    fail("invalid checker pattern: \(error)")
  }
  let range = NSRange(text.startIndex..., in: text)
  return expression.matches(in: text, range: range).compactMap { match in
    guard match.numberOfRanges > 1,
      let range = Range(match.range(at: 1), in: text)
    else { return nil }
    return String(text[range])
  }
}

struct InvalidFormatDirective: Error {}

func placeholders(in value: String) throws -> [String] {
  var result: [String] = []
  var index = value.startIndex
  while index < value.endIndex {
    guard value[index] == "%" else {
      index = value.index(after: index)
      continue
    }

    let remainder = value[index...]
    if remainder.hasPrefix("%%") {
      index = value.index(index, offsetBy: 2)
    } else if remainder.hasPrefix("%lld") {
      result.append("%lld")
      index = value.index(index, offsetBy: 4)
    } else if remainder.hasPrefix("%@") {
      result.append("%@")
      index = value.index(index, offsetBy: 2)
    } else {
      throw InvalidFormatDirective()
    }
  }
  return result.sorted()
}

func checkPlaceholderParser() {
  do {
    guard try placeholders(in: "%lld%% used") == ["%lld"],
      try placeholders(in: "%@") == ["%@"]
    else {
      fail("placeholder parser rejected a supported format")
    }
  } catch {
    fail("placeholder parser rejected a supported format")
  }

  for value in ["%n", "%", "%d"] {
    do {
      _ = try placeholders(in: value)
      fail("placeholder parser accepted unsupported format \(value)")
    } catch is InvalidFormatDirective {
      continue
    } catch {
      fail("placeholder parser failed unexpectedly for \(value): \(error)")
    }
  }
}

checkPlaceholderParser()

guard let catalogData = FileManager.default.contents(atPath: catalogPath),
  let catalog = try? JSONSerialization.jsonObject(with: catalogData) as? [String: Any],
  catalog["sourceLanguage"] as? String == "en-US",
  let strings = catalog["strings"] as? [String: Any]
else {
  fail("catalog is unreadable or sourceLanguage is not en-US")
}

var sourceKeys = Set<String>()
let keyPattern = #"(?:L10n\.)?string\(\s*"((?:\\.|[^"\\])*)""#
let sourceURLs: [URL]
do {
  sourceURLs = try FileManager.default.contentsOfDirectory(
    at: URL(fileURLWithPath: sourceDirectory),
    includingPropertiesForKeys: nil
  ).filter { $0.pathExtension == "swift" }
} catch {
  fail("could not read GUI sources: \(error)")
}
for url in sourceURLs {
  guard let source = try? String(contentsOf: url, encoding: .utf8) else {
    fail("could not read \(url.path)")
  }
  sourceKeys.formUnion(captures(keyPattern, in: source))
}

let catalogKeys = Set(strings.keys)
let missingKeys = sourceKeys.subtracting(catalogKeys).sorted()
let obsoleteKeys = catalogKeys.subtracting(sourceKeys).sorted()
if !missingKeys.isEmpty { fail("missing keys: \(missingKeys.joined(separator: ", "))") }
if !obsoleteKeys.isEmpty { fail("obsolete keys: \(obsoleteKeys.joined(separator: ", "))") }

for key in catalogKeys.sorted() {
  guard let entry = strings[key] as? [String: Any],
    let localizations = entry["localizations"] as? [String: Any]
  else {
    fail("\(key) has no localizations")
  }
  let locales = Set(localizations.keys)
  guard locales == requiredLocales else {
    fail("\(key) has locales \(locales.sorted()), expected \(requiredLocales.sorted())")
  }
  let sourcePlaceholders: [String]
  do {
    sourcePlaceholders = try placeholders(in: key)
  } catch {
    fail("\(key) has an unsupported source format directive")
  }
  for locale in requiredLocales {
    guard let localization = localizations[locale] as? [String: Any],
      let unit = localization["stringUnit"] as? [String: Any],
      unit["state"] as? String == "translated",
      let value = unit["value"] as? String,
      !value.isEmpty
    else {
      fail("\(key) has no completed \(locale) translation")
    }
    if locale == "en-US", value != key {
      fail("\(key) must use its source value for en-US")
    }
    let localizedPlaceholders: [String]
    do {
      localizedPlaceholders = try placeholders(in: value)
    } catch {
      fail("\(key) has an unsupported format directive in \(locale)")
    }
    if localizedPlaceholders != sourcePlaceholders {
      fail("\(key) has divergent placeholders in \(locale)")
    }
  }
}

print("Localization catalog passed (\(catalogKeys.count) keys, en-US and pt-BR).")
