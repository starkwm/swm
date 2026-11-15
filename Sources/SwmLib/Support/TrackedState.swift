struct TrackedState<Value: Equatable>: CustomStringConvertible {
  private(set) var current: Value?

  private(set) var last: Value?

  private var lastKnown: Value?

  var description: String {
    "current: \(current.map { "\($0)" } ?? "nil"), last: \(last.map { "\($0)" } ?? "nil")"
  }

  init(current: Value?) {
    self.current = current
    last = current
  }

  mutating func update(to value: Value) {
    guard value != current else { return }

    let previous = current ?? lastKnown
    lastKnown = nil
    current = value
    if previous != value {
      last = previous
    }
  }

  mutating func invalidate() {
    guard let current else { return }

    lastKnown = current
    self.current = nil
  }
}
