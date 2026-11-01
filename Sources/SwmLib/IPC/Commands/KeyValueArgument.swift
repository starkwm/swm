/// A `key=value` or `key!=value` argument that registers a rule or signal.
///
/// The first `=` ends the key, so values may contain `=` and `!=`. A key ending in `!`
/// inverts the filter it names.
struct KeyValueArgument {
  /// The key without its `!` suffix.
  let key: String

  /// The text after the first `=`.
  let value: String

  /// Whether the key ends in `!`.
  let inverted: Bool

  /// The key as written, including any `!` suffix.
  var rawKey: String { inverted ? key + "!" : key }

  /// Parse an argument, or return nil when it has no `=`, key, or value.
  init?(_ argument: String) {
    guard let separator = argument.firstIndex(of: "=") else { return nil }
    let rawKey = argument[..<separator]
    inverted = rawKey.hasSuffix("!")
    key = String(inverted ? rawKey.dropLast() : rawKey)
    value = String(argument[argument.index(after: separator)...])
    guard !key.isEmpty, !value.isEmpty else { return nil }
  }
}
