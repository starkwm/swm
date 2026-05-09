/// Describes whether a numeric command argument replaces or adjusts a value.
enum ChangeMode: String {
  /// Treat command values as absolute replacements.
  case absolute = "abs"

  /// Treat command values as relative deltas.
  case relative = "rel"
}
