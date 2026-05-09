/// Tracks a current value and the previous distinct value.
struct TrackedState<Value: Equatable> {
  /// Current tracked value.
  private(set) var current: Value?

  /// Previous tracked value.
  private(set) var last: Value?

  /// Create tracked state with the same current and previous value.
  init(current: Value?) {
    self.current = current
    last = current
  }

  /// Update the current value and preserve the previous distinct value.
  mutating func update(to value: Value) {
    guard value != current else { return }

    last = current
    current = value
  }
}
