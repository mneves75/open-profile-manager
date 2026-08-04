import Foundation
import Testing

@testable import ProfileCore

@Suite("Process execution")
struct ProcessExecutorTests {
  @Test("Exec failure remains a typed launch error")
  func execFailure() {
    let plan = ProcessPlan(
      executableURL: URL(fileURLWithPath: "/does-not-exist/opm-test"),
      arguments: [],
      environment: [:]
    )

    #expect(throws: ProfileCoreError.processLaunchFailed("opm-test")) {
      try ProcessExecutor.replaceCurrentProcess(with: plan)
    }
  }

  @Test("Exec rejects embedded NUL before calling Darwin")
  func embeddedNUL() {
    let plan = ProcessPlan(
      executableURL: URL(fileURLWithPath: "/usr/bin/true"),
      arguments: ["invalid\0argument"],
      environment: [:]
    )

    #expect(throws: ProfileCoreError.processLaunchFailed("true")) {
      try ProcessExecutor.replaceCurrentProcess(with: plan)
    }
  }
}
