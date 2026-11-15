import Darwin
import Foundation
import Testing

@testable import SwmLib

@Suite("ShellSignalExecutor")
struct ShellSignalExecutorTests {
  @Test("execute: reads standard input from /dev/null", .timeLimit(.minutes(1)))
  func executeReadsStandardInputFromDevNull() async {
    let outcome = await run("[ /dev/stdin -ef /dev/null ]", timeout: .seconds(10))
    #expect(outcome == .exited(0))
  }

  @Test("execute: stops a timed-out action and the commands it started", .timeLimit(.minutes(1)))
  func executeStopsATimedOutActionAndTheCommandsItStarted() async throws {
    let pidFile = FileManager.default.temporaryDirectory
      .appendingPathComponent("swm-signal-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: pidFile) }

    let outcome = await run(
      "sleep 30 & echo $! > '\(pidFile.path)'; wait",
      timeout: .milliseconds(200)
    )

    #expect(outcome == .timedOut)
    let text = try String(contentsOf: pidFile, encoding: .utf8)
    let child = try #require(pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)))
    var alive = true
    for _ in 0..<50 where alive {
      alive = kill(child, 0) == 0
      if alive { try await Task.sleep(for: .milliseconds(20)) }
    }
    #expect(!alive)
  }

  private func run(_ action: String, timeout: Duration) async -> SignalActionOutcome {
    await withCheckedContinuation { continuation in
      ShellSignalExecutor.execute(action: action, environment: [:], timeout: timeout) {
        continuation.resume(returning: $0)
      }
    }
  }
}
