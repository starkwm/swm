struct TrackedState<Value: Equatable> {
  private(set) var current: Value?
  private(set) var last: Value?

  init(current: Value?) {
    self.current = current
    last = nil
  }

  mutating func update(to value: Value) {
    guard value != current else { return }

    last = current
    current = value
  }
}
