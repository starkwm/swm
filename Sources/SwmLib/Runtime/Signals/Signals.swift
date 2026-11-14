import Foundation

/// Thread-safe in-memory registry for user signals.
public final class Signals {
  /// Shared signal registry used by the daemon.
  public static let shared = Signals()

  private let lock = NSLock()
  private let executionQueue: SignalExecutionQueue
  private var signals = [Signal]()

  /// Create an empty signal service.
  init(executionQueue: SignalExecutionQueue = SignalExecutionQueue()) {
    self.executionQueue = executionQueue
  }

  /// Register a signal, preserving insertion order.
  func add(_ signal: Signal) throws {
    try lock.withLock {
      try signals.appendUniquelyLabeled(signal, kind: "signal", label: \.label)
    }
  }

  /// Remove a signal by one-based index or label.
  func remove(selector: String) throws {
    try lock.withLock {
      try signals.remove(selector: selector, kind: "signal", label: \.label)
    }
  }

  /// Remove every signal.
  func removeAll() {
    replaceAll([])
  }

  /// Replace every signal at once, so no event sees a partial registry.
  func replaceAll(_ signals: [Signal]) {
    lock.withLock { self.signals = signals }
  }

  /// Return registered signals with their one-based indexes.
  func list() -> [IndexedSignal] {
    lock.withLock {
      signals.enumerated().map { index, signal in
        IndexedSignal(index: index + 1, signal: signal)
      }
    }
  }

  /// Check for listeners before reading Accessibility data for a window payload.
  func hasSubscribers(for event: SignalEvent) -> Bool {
    lock.withLock { signals.contains { $0.event == event } }
  }

  /// Execute actions whose registrations match the payload.
  ///
  /// Moves and resizes arrive in bursts while a window is dragged, so a registration's pending
  /// action for the same window runs once with the latest event.
  func emit(_ payload: SignalPayload) {
    let matches = lock.withLock {
      signals.enumerated().filter { $0.element.matches(payload) }
    }

    for (index, signal) in matches {
      var coalescingKey: String?
      if payload.event == .windowMoved || payload.event == .windowResized,
        let windowID = payload.environment["SWM_WINDOW_ID"]
      {
        coalescingKey =
          "\(index)\u{0}\(signal.action)\u{0}\(payload.event.rawValue)\u{0}\(windowID)"
      }
      guard
        executionQueue.enqueue(
          action: signal.action,
          environment: payload.environment,
          coalescingKey: coalescingKey
        )
      else {
        log("signal action queue is full; dropping action", level: .warn)
        continue
      }
    }
  }
}

extension Signals: @unchecked Sendable {}

/// A signal paired with its current registry index.
struct IndexedSignal: Equatable, Sendable {
  let index: Int
  let signal: Signal
}
