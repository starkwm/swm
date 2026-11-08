/// Tracks a current value and the previous distinct value.
struct TrackedState<Value: Equatable>: CustomStringConvertible {
  /// Current tracked value.
  private(set) var current: Value?

  /// Previous tracked value.
  private(set) var last: Value?

  /// Value that was current before it became unknown.
  private var lastKnown: Value?

  /// Current and previous values formatted for logs.
  var description: String {
    "current: \(current.map { "\($0)" } ?? "nil"), last: \(last.map { "\($0)" } ?? "nil")"
  }

  /// Create tracked state with the same current and previous value.
  init(current: Value?) {
    self.current = current
    last = current
  }

  /// Update the current value and preserve the previous distinct value.
  mutating func update(to value: Value) {
    guard value != current else { return }

    let previous = current ?? lastKnown
    lastKnown = nil
    current = value
    if previous != value {
      last = previous
    }
  }

  /// Mark the current value unknown, keeping it as history for the next update.
  mutating func invalidate() {
    guard let current else { return }

    lastKnown = current
    self.current = nil
  }
}
