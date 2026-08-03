import Darwin
import Foundation

enum BoundedFile {
  static func readRegularFile(
    at url: URL,
    maximumBytes: Int,
    operation: String
  ) throws -> Data {
    guard maximumBytes >= 0 else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
    guard descriptor >= 0 else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    defer { _ = close(descriptor) }

    var information = stat()
    guard fstat(descriptor, &information) == 0,
      information.st_mode & S_IFMT == S_IFREG,
      information.st_size >= 0,
      information.st_size <= off_t(maximumBytes)
    else {
      throw ProfileCoreError.filesystem(operation: operation)
    }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: min(maximumBytes + 1, 65_536))
    while true {
      let readCount = buffer.withUnsafeMutableBytes { rawBuffer in
        Darwin.read(descriptor, rawBuffer.baseAddress, rawBuffer.count)
      }
      if readCount < 0, errno == EINTR {
        continue
      }
      guard readCount >= 0 else {
        throw ProfileCoreError.filesystem(operation: operation)
      }
      guard readCount > 0 else { return data }
      guard data.count <= maximumBytes - readCount else {
        throw ProfileCoreError.filesystem(operation: operation)
      }
      data.append(contentsOf: buffer.prefix(readCount))
    }
  }
}
