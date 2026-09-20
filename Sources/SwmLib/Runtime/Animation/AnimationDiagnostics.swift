import Foundation

/// Opt-in, bounded latency samples. No window titles or geometry are recorded.
final class AnimationDiagnostics: @unchecked Sendable {
  struct Sample: Sendable {
    let operation: String
    let processID: pid_t
    let milliseconds: Double
    let missedDeadline: Bool
  }

  static let shared = AnimationDiagnostics(
    enabled: ProcessInfo.processInfo.environment["SWM_ANIMATION_DIAGNOSTICS"] == "1"
  )

  let enabled: Bool
  private let lock = NSLock()
  private var samples = [Sample]()
  private var total = 0

  init(enabled: Bool) {
    self.enabled = enabled
  }

  func measure<T>(_ operation: String, processID: pid_t = 0, _ body: () -> T) -> T {
    guard enabled else { return body() }
    let start = ContinuousClock.now
    defer { record(operation, processID: processID, since: start) }
    return body()
  }

  func record(
    _ operation: String,
    processID: pid_t = 0,
    since start: ContinuousClock.Instant,
    missedDeadline: Bool = false
  ) {
    guard enabled else { return }
    let milliseconds = start.duration(to: .now) / .milliseconds(1)
    let sample = Sample(
      operation: operation,
      processID: processID,
      milliseconds: milliseconds,
      missedDeadline: missedDeadline || (operation == "tick" && milliseconds > 1000 / 60)
    )
    let report = lock.withLock {
      if samples.count == 512 { samples.removeFirst() }
      samples.append(sample)
      total += 1
      return total % 120 == 0
    }
    if report {
      let grouped = Dictionary(grouping: snapshot()) { "\($0.operation) pid=\($0.processID)" }
      for key in grouped.keys.sorted() {
        guard let values = grouped[key] else { continue }
        let mean = values.reduce(0) { $0 + $1.milliseconds } / Double(values.count)
        let maximum = values.map(\.milliseconds).max() ?? 0
        log(
          "animation \(key) n=\(values.count) mean_ms=\(mean) max_ms=\(maximum) missed=\(values.filter(\.missedDeadline).count)",
          level: .info
        )
      }
    }
  }

  func snapshot() -> [Sample] {
    lock.withLock { samples }
  }
}
