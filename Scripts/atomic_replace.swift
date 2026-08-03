import Darwin
import Foundation

guard CommandLine.arguments.count == 3 else {
  FileHandle.standardError.write(Data("usage: atomic_replace.swift SOURCE DESTINATION\n".utf8))
  exit(64)
}

let source = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let destination = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
guard source.deletingLastPathComponent() == destination.deletingLastPathComponent() else {
  FileHandle.standardError.write(Data("source and destination must be siblings\n".utf8))
  exit(64)
}

func fileInformation(at url: URL) -> stat? {
  var information = stat()
  guard lstat(url.path, &information) == 0 else { return nil }
  return information
}

guard let sourceInformation = fileInformation(at: source) else {
  FileHandle.standardError.write(Data("replacement source does not exist\n".utf8))
  exit(66)
}

let replacementResult: Int32
if let destinationInformation = fileInformation(at: destination) {
  guard sourceInformation.st_mode & S_IFMT == destinationInformation.st_mode & S_IFMT else {
    FileHandle.standardError.write(Data("replacement source and destination types differ\n".utf8))
    exit(65)
  }
  replacementResult = source.path.withCString { sourcePath in
    destination.path.withCString { destinationPath in
      renameatx_np(
        AT_FDCWD,
        sourcePath,
        AT_FDCWD,
        destinationPath,
        UInt32(RENAME_SWAP)
      )
    }
  }
} else {
  replacementResult = rename(source.path, destination.path)
}

guard replacementResult == 0 else {
  let message = String(cString: strerror(errno))
  FileHandle.standardError.write(Data("atomic replacement failed: \(message)\n".utf8))
  exit(74)
}

if FileManager.default.fileExists(atPath: source.path) {
  do {
    try FileManager.default.removeItem(at: source)
  } catch {
    FileHandle.standardError.write(
      Data("warning: the previous installation remains at the staging path\n".utf8)
    )
  }
}
