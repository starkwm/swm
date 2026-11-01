import Foundation

/// Window filters and optional management and placement actions.
struct WindowRule: Encodable {
  /// Keys accepted by rule registration.
  static let keys = ["label", "app", "title", "bundle-id", "manage", "grid", "display"]

  /// Filter keys that also accept `key!=value`, requiring the value not to match.
  static let invertibleKeys: Set = ["app", "title", "bundle-id"]

  /// Parse and validate a registration before changing runtime state.
  static func parse(arguments: [String]) throws -> WindowRule {
    var values = [String: String]()
    for argument in arguments {
      guard let item = KeyValueArgument(argument) else {
        throw IPCCommandError.invalidRequest("invalid rule argument: \(argument)")
      }
      guard keys.contains(item.key), !item.inverted || invertibleKeys.contains(item.key) else {
        let accepted = keys.flatMap { invertibleKeys.contains($0) ? [$0, $0 + "!"] : [$0] }
        throw IPCCommandError.invalidRequest(
          "invalid rule argument: \(argument); expected key=value with one of "
            + accepted.joined(separator: ", ")
        )
      }
      guard values[item.key] == nil, values[item.key + "!"] == nil else {
        throw IPCCommandError.invalidRequest("duplicate rule argument: \(item.key)")
      }
      values[item.rawKey] = item.value
    }
    if let manage = values["manage"], !["on", "off"].contains(manage) {
      throw IPCCommandError.invalidRequest("invalid rule manage value: \(manage)")
    }
    guard values["manage"] != nil || values["grid"] != nil || values["display"] != nil else {
      throw IPCCommandError.invalidRequest("rule requires manage, grid, or display")
    }
    if let label = values["label"], Int(label) != nil {
      throw IPCCommandError.invalidRequest("rule label must not be an integer")
    }
    return try WindowRule(values: values)
  }

  let label: String?
  let manage: Bool?
  let grid: WindowGrid?
  let display: RuleDisplayTarget?
  private let values: [String: String]
  private let bundleID: String?
  private let app: NSRegularExpression?
  private let title: NSRegularExpression?

  private init(values: [String: String]) throws {
    self.values = values
    self.label = values["label"]
    self.manage = values["manage"].map { $0 == "on" }
    if let value = values["grid"] {
      guard let grid = WindowGrid(argument: value) else {
        throw IPCCommandError.invalidRequest("invalid rule grid: \(value)")
      }
      self.grid = grid
    } else {
      grid = nil
    }
    if let value = values["display"] {
      guard let display = RuleDisplayTarget(argument: value) else {
        throw IPCCommandError.invalidRequest("invalid rule display: \(value)")
      }
      self.display = display
    } else {
      display = nil
    }
    self.bundleID = values["bundle-id"] ?? values["bundle-id!"]
    do {
      app = try (values["app"] ?? values["app!"]).map { try NSRegularExpression(pattern: $0) }
      title = try (values["title"] ?? values["title!"]).map { try NSRegularExpression(pattern: $0) }
    } catch {
      throw IPCCommandError.invalidRequest("invalid rule regex: \(error.localizedDescription)")
    }
  }

  func matches(_ window: TilingWindowSnapshot) -> Bool {
    matches(bundleID, exactly: window.bundleID, inverted: values["bundle-id!"] != nil)
      && matches(app, value: window.app, inverted: values["app!"] != nil)
      && matches(title, value: window.title, inverted: values["title!"] != nil)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(values)
  }

  private func matches(_ expected: String?, exactly value: String?, inverted: Bool) -> Bool {
    guard let expected else { return true }
    guard let value else { return false }
    return (value == expected) != inverted
  }

  private func matches(_ regex: NSRegularExpression?, value: String?, inverted: Bool) -> Bool {
    guard let regex else { return true }
    guard let value else { return false }
    let matched =
      regex.firstMatch(in: value, range: NSRange(value.startIndex..<value.endIndex, in: value))
      != nil
    return inverted ? !matched : matched
  }
}
