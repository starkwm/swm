struct KeyValueArgument {
  let key: String

  let value: String

  let inverted: Bool

  var rawKey: String { inverted ? key + "!" : key }

  init?(_ argument: String) {
    guard let separator = argument.firstIndex(of: "=") else { return nil }
    let rawKey = argument[..<separator]
    inverted = rawKey.hasSuffix("!")
    key = String(inverted ? rawKey.dropLast() : rawKey)
    value = String(argument[argument.index(after: separator)...])
    guard !key.isEmpty, !value.isEmpty else { return nil }
  }
}
