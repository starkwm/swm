import Foundation

/// Thread-safe in-memory registry for user signals.
public final class SignalManager {
  /// Shared signal registry used by the daemon.
  public static let shared = SignalManager()

  private let lock = NSLock()
  private var signals = [Signal]()

  /// Create an empty signal manager.
  init() {}

  /// Register a signal, preserving insertion order.
  func add(_ signal: Signal) throws {
    try lock.withLock {
      if let label = signal.label, signals.contains(where: { $0.label == label }) {
        throw IPCCommandError.invalidRequest("signal label already exists: \(label)")
      }

      signals.append(signal)
    }
  }

  /// Remove a signal by one-based index or label.
  func remove(selector: String) throws {
    try lock.withLock {
      if let index = Int(selector) {
        guard index > 0, signals.indices.contains(index - 1) else {
          throw IPCCommandError.invalidRequest("signal not found: \(selector)")
        }

        signals.remove(at: index - 1)
        return
      }

      guard let index = signals.firstIndex(where: { $0.label == selector }) else {
        throw IPCCommandError.invalidRequest("signal not found: \(selector)")
      }

      signals.remove(at: index)
    }
  }

  /// Return registered signals with their one-based indexes.
  func list() -> [IndexedSignal] {
    lock.withLock {
      signals.enumerated().map { index, signal in
        IndexedSignal(index: index + 1, signal: signal)
      }
    }
  }

  /// Execute actions whose registrations match the payload.
  func emit(_ payload: SignalPayload) {
    let matches = lock.withLock {
      signals.filter { $0.matches(payload) }
    }

    for signal in matches {
      ShellSignalExecutor.execute(action: signal.action, environment: payload.environment)
    }
  }
}

extension SignalManager: @unchecked Sendable {}

/// A signal paired with its current registry index.
struct IndexedSignal: Equatable, Sendable {
  let index: Int
  let signal: Signal
}
