/// Direction through a cyclic sequence.
public enum CycleDirection: String, Equatable, Sendable {
  /// Select the following value, wrapping at the end.
  case next

  /// Select the preceding value, wrapping at the beginning.
  case prev
}
