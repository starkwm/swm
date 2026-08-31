/// Direction through a cyclic sequence.
enum CycleDirection: String, Equatable {
  /// Select the following value, wrapping at the end.
  case next

  /// Select the preceding value, wrapping at the beginning.
  case prev
}
