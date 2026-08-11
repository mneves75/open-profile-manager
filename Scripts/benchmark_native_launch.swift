import CoreGraphics
import Darwin
import Foundation

enum LaunchBenchmarkError: Error, CustomStringConvertible {
  case invalidArguments
  case notExecutable(String)
  case windowTimeout

  var description: String {
    switch self {
    case .invalidArguments:
      "usage: swift Scripts/benchmark_native_launch.swift <app-executable> [samples]"
    case .notExecutable(let path):
      "not an executable file: \(path)"
    case .windowTimeout:
      "the app did not create an on-screen layer-zero window within five seconds"
    }
  }
}

func hasVisibleWindow(processID: Int32) -> Bool {
  let windows =
    CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements],
      kCGNullWindowID
    ) as? [[String: Any]] ?? []
  return windows.contains { window in
    (window[kCGWindowOwnerPID as String] as? Int) == Int(processID)
      && (window[kCGWindowLayer as String] as? Int) == 0
  }
}

func percentile(_ sorted: [Double], percentage: Double) -> Double {
  let rank = max(1, Int(ceil(Double(sorted.count) * percentage)))
  return sorted[rank - 1]
}

func run() throws {
  guard CommandLine.arguments.count == 2 || CommandLine.arguments.count == 3 else {
    throw LaunchBenchmarkError.invalidArguments
  }
  let executablePath = CommandLine.arguments[1]
  guard FileManager.default.isExecutableFile(atPath: executablePath) else {
    throw LaunchBenchmarkError.notExecutable(executablePath)
  }
  let sampleCount = CommandLine.arguments.count == 3 ? Int(CommandLine.arguments[2]) : 10
  guard let sampleCount, sampleCount > 0 else {
    throw LaunchBenchmarkError.invalidArguments
  }

  var load = [Double](repeating: 0, count: 3)
  _ = getloadavg(&load, Int32(load.count))
  var samples: [Double] = []
  samples.reserveCapacity(sampleCount)

  for _ in 0..<sampleCount {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executablePath)
    let started = DispatchTime.now().uptimeNanoseconds
    try process.run()
    let deadline = started + 5_000_000_000
    while !hasVisibleWindow(processID: process.processIdentifier)
      && DispatchTime.now().uptimeNanoseconds < deadline
    {
      usleep(1_000)
    }
    guard hasVisibleWindow(processID: process.processIdentifier) else {
      process.terminate()
      process.waitUntilExit()
      throw LaunchBenchmarkError.windowTimeout
    }
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
    samples.append(elapsed)
    process.terminate()
    process.waitUntilExit()
    usleep(100_000)
  }

  let sorted = samples.sorted()
  print("metric=process-run-to-on-screen-layer-zero-window")
  print("samples_ms=\(sorted.map { String(format: "%.3f", $0) }.joined(separator: ","))")
  print(
    String(
      format: "p50_ms=%.3f p95_ms=%.3f load=%.2f/%.2f/%.2f",
      percentile(sorted, percentage: 0.50),
      percentile(sorted, percentage: 0.95),
      load[0],
      load[1],
      load[2]
    )
  )
}

do {
  try run()
} catch {
  FileHandle.standardError.write(Data("\(error)\n".utf8))
  exit(1)
}
