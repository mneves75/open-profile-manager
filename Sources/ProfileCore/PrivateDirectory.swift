import Darwin
import Foundation

enum PrivateDirectory {
  static func ensure(_ url: URL, operation: String) throws {
    let components = try physicalPathComponents(url, operation: operation)
    var parentDescriptor = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
    guard parentDescriptor >= 0 else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    defer { _ = close(parentDescriptor) }
    var enteredPrivatePath = false

    for (index, component) in components.enumerated() {
      var childDescriptor = openat(
        parentDescriptor,
        component,
        O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
      )
      var wasCreated = false
      if childDescriptor < 0 {
        guard errno == ENOENT else {
          throw ProfileCoreError.filesystem(operation: operation)
        }
        enteredPrivatePath = true
        if mkdirat(parentDescriptor, component, S_IRWXU) == 0 {
          wasCreated = true
        } else {
          guard errno == EEXIST else {
            throw ProfileCoreError.filesystem(operation: operation)
          }
        }
        childDescriptor = openat(
          parentDescriptor,
          component,
          O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
      }
      guard childDescriptor >= 0 else {
        throw ProfileCoreError.filesystem(operation: operation)
      }
      if wasCreated {
        guard fchmod(childDescriptor, S_IRWXU) == 0 else {
          _ = close(childDescriptor)
          throw ProfileCoreError.filesystem(operation: "set private directory permissions")
        }
        do {
          try removeExtendedACL(descriptor: childDescriptor, operation: operation)
        } catch {
          _ = close(childDescriptor)
          throw error
        }
      }
      if enteredPrivatePath || index == components.indices.last {
        do {
          try validatePrivateDirectory(
            descriptor: childDescriptor,
            operation: operation,
            displayPath: index == components.indices.last ? url.path : nil
          )
        } catch {
          _ = close(childDescriptor)
          throw error
        }
      } else {
        do {
          try validateTrustedAncestor(descriptor: childDescriptor, operation: operation)
        } catch {
          _ = close(childDescriptor)
          throw error
        }
      }
      if wasCreated {
        do {
          try syncDirectory(parentDescriptor, operation: operation)
        } catch {
          _ = close(childDescriptor)
          throw error
        }
      }
      _ = close(parentDescriptor)
      parentDescriptor = childDescriptor
    }
  }

  static func validate(_ url: URL, operation: String) throws {
    let descriptor = try openValidatedDirectory(url, operation: operation)
    _ = close(descriptor)
  }

  static func openValidatedDirectory(_ url: URL, operation: String) throws -> Int32 {
    let descriptor = try openExistingDirectory(url, operation: operation)
    do {
      try validatePrivateDirectory(
        descriptor: descriptor,
        operation: operation,
        displayPath: url.path
      )
    } catch {
      _ = close(descriptor)
      throw error
    }
    return descriptor
  }

  static func validateNoExtendedACL(descriptor: Int32, operation: String) throws {
    errno = 0
    if let accessControlList = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) {
      acl_free(UnsafeMutableRawPointer(accessControlList))
      throw ProfileCoreError.filesystem(operation: operation)
    }
    guard errno == ENOENT || errno == EOPNOTSUPP else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
  }

  private static func openExistingDirectory(_ url: URL, operation: String) throws -> Int32 {
    let components = try physicalPathComponents(url, operation: operation)
    var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
    guard descriptor >= 0 else {
      throw ProfileCoreError.filesystem(operation: operation)
    }

    for component in components {
      let childDescriptor = openat(
        descriptor,
        component,
        O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
      )
      guard childDescriptor >= 0 else {
        _ = close(descriptor)
        throw ProfileCoreError.filesystem(operation: operation)
      }
      do {
        try validateTrustedAncestor(descriptor: childDescriptor, operation: operation)
      } catch {
        _ = close(childDescriptor)
        _ = close(descriptor)
        throw error
      }
      _ = close(descriptor)
      descriptor = childDescriptor
    }
    return descriptor
  }

  static func physicalPathComponents(_ url: URL, operation: String) throws -> [String] {
    guard url.path.hasPrefix("/") else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    var components = Array(url.pathComponents.dropFirst())
    guard !components.isEmpty else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    if components[0] == "var" || components[0] == "tmp" {
      components.insert("private", at: 0)
    }
    return components
  }

  static func physicalIdentityURL(_ url: URL, operation: String) throws -> URL {
    let components = try physicalPathComponents(url, operation: operation)
    var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
    guard descriptor >= 0 else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    defer { _ = close(descriptor) }

    var existingComponentCount = 0
    for component in components {
      let childDescriptor = openat(
        descriptor,
        component,
        O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
      )
      if childDescriptor < 0 {
        guard errno == ENOENT || errno == ENOTDIR || errno == ELOOP else {
          throw ProfileCoreError.filesystem(operation: operation)
        }
        break
      }
      _ = close(descriptor)
      descriptor = childDescriptor
      existingComponentCount += 1
    }

    var pathBuffer = [CChar](repeating: 0, count: Int(PATH_MAX))
    let pathResult = pathBuffer.withUnsafeMutableBufferPointer { buffer in
      fcntl(descriptor, F_GETPATH_NOFIRMLINK, buffer.baseAddress!)
    }
    guard pathResult == 0 else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    let identityPathBytes = pathBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    var identityURL = URL(
      fileURLWithPath: String(decoding: identityPathBytes, as: UTF8.self),
      isDirectory: true
    )
    for component in components.dropFirst(existingComponentCount) {
      identityURL.appendPathComponent(component, isDirectory: true)
    }
    return identityURL.standardizedFileURL
  }

  private static func validatePrivateDirectory(
    descriptor: Int32,
    operation: String,
    displayPath: String? = nil
  ) throws {
    var information = stat()
    guard fstat(descriptor, &information) == 0,
      information.st_mode & S_IFMT == S_IFDIR,
      information.st_uid == geteuid()
    else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    guard information.st_mode & 0o777 == S_IRWXU else {
      if let displayPath {
        throw ProfileCoreError.unsafeDirectoryPermissions(displayPath)
      }
      throw ProfileCoreError.filesystem(operation: operation)
    }

    try validateNoExtendedACL(descriptor: descriptor, operation: operation)
  }

  private static func validateTrustedAncestor(descriptor: Int32, operation: String) throws {
    var information = stat()
    let currentUser = geteuid()
    guard fstat(descriptor, &information) == 0,
      information.st_mode & S_IFMT == S_IFDIR,
      information.st_uid == 0 || information.st_uid == currentUser
    else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    let isWritableByOthers = information.st_mode & (S_IWGRP | S_IWOTH) != 0
    let isRootOwnedStickyDirectory =
      information.st_uid == 0 && information.st_mode & S_ISVTX != 0
    guard !isWritableByOthers || isRootOwnedStickyDirectory else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    try validateTrustedAncestorACL(descriptor: descriptor, operation: operation)
  }

  private static func validateTrustedAncestorACL(descriptor: Int32, operation: String) throws {
    errno = 0
    guard let accessControlList = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
      guard errno == ENOENT || errno == EOPNOTSUPP else {
        throw ProfileCoreError.filesystem(operation: operation)
      }
      return
    }
    defer { acl_free(UnsafeMutableRawPointer(accessControlList)) }

    var entry: acl_entry_t?
    var entryID = Int32(ACL_FIRST_ENTRY.rawValue)
    while true {
      errno = 0
      let result = acl_get_entry(accessControlList, entryID, &entry)
      if result != 0 {
        guard errno == EINVAL else {
          throw ProfileCoreError.filesystem(operation: operation)
        }
        break
      }
      guard let entry else {
        throw ProfileCoreError.filesystem(operation: operation)
      }
      var tag = ACL_UNDEFINED_TAG
      guard acl_get_tag_type(entry, &tag) == 0, tag == ACL_EXTENDED_DENY else {
        throw ProfileCoreError.filesystem(operation: operation)
      }
      entryID = Int32(ACL_NEXT_ENTRY.rawValue)
    }
  }

  private static func syncDirectory(_ descriptor: Int32, operation: String) throws {
    var result: Int32
    repeat {
      result = fsync(descriptor)
    } while result != 0 && errno == EINTR
    guard result == 0 || errno == EINVAL || errno == EOPNOTSUPP else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
  }

  static func removeExtendedACL(descriptor: Int32, operation: String) throws {
    guard let emptyAccessControlList = acl_init(0) else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    defer { acl_free(UnsafeMutableRawPointer(emptyAccessControlList)) }
    errno = 0
    let result = acl_set_fd_np(descriptor, emptyAccessControlList, ACL_TYPE_EXTENDED)
    guard result == 0 || errno == EOPNOTSUPP else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
  }

  static func validateCreationPath(_ url: URL, operation: String) throws {
    let components = try physicalPathComponents(url, operation: operation)
    var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
    guard descriptor >= 0 else {
      throw ProfileCoreError.filesystem(operation: operation)
    }
    defer { _ = close(descriptor) }

    for component in components {
      let childDescriptor = openat(
        descriptor,
        component,
        O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
      )
      if childDescriptor < 0 {
        guard errno == ENOENT else {
          throw ProfileCoreError.filesystem(operation: operation)
        }
        return
      }
      do {
        try validateTrustedAncestor(descriptor: childDescriptor, operation: operation)
      } catch {
        _ = close(childDescriptor)
        throw error
      }
      _ = close(descriptor)
      descriptor = childDescriptor
    }
    try validatePrivateDirectory(
      descriptor: descriptor,
      operation: operation,
      displayPath: url.path
    )
  }
}
