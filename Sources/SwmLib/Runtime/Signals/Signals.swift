import Foundation

public final class Signals {
  public static let shared = Signals()

  private let lock = NSLock()
  private let executionQueue: SignalExecutionQueue
  private var signals = [Signal]()

  init(executionQueue: SignalExecutionQueue = SignalExecutionQueue()) {
    self.executionQueue = executionQueue
  }

  func add(_ signal: Signal) throws {
    try lock.withLock {
      try signals.appendUniquelyLabeled(signal, kind: "signal", label: \.label)
    }
  }

  func remove(selector: String) throws {
    try lock.withLock {
      try signals.remove(selector: selector, kind: "signal", label: \.label)
    }
  }

  func removeAll() {
    replaceAll([])
  }

  func replaceAll(_ signals: [Signal]) {
    lock.withLock { self.signals = signals }
  }

  func list() -> [IndexedSignal] {
    lock.withLock {
      signals.enumerated().map { index, signal in
        IndexedSignal(index: index + 1, signal: signal)
      }
    }
  }

  func hasSubscribers(for event: SignalEvent) -> Bool {
    lock.withLock { signals.contains { $0.event == event } }
  }

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

struct IndexedSignal: Equatable, Sendable {
  let index: Int
  let signal: Signal
}
