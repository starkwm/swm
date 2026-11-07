import Foundation

/// Window filters and optional management and placement actions.
struct WindowRule: Encodable {
  /// Keys accepted by rule registration.
  static let keys = ["label", "app", "title", "bundle-id", "manage", "grid", "display", "space"]

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
    guard ["manage", "grid", "display", "space"].contains(where: { values[$0] != nil }) else {
      throw IPCCommandError.invalidRequest("rule requires manage, grid, display, or space")
    }
    guard values["display"] == nil || values["space"] == nil else {
      throw IPCCommandError.invalidRequest("rule accepts display or space, not both")
    }
    if let label = values["label"], Int(label) != nil {
      throw IPCCommandError.invalidRequest("rule label must not be an integer")
    }
    return try WindowRule(values: values)
  }

  private static func textFilter(key: String, in values: [String: String]) throws -> TextFilter? {
    if let pattern = values[key] { return try TextFilter(pattern: pattern) }
    if let pattern = values[key + "!"] { return try TextFilter(pattern: pattern, inverted: true) }
    return nil
  }

  let label: String?
  let manage: Bool?
  let grid: WindowGrid?
  let display: RuleDisplayTarget?
  /// One-based Space index, matching `swm query spaces`.
  let space: Int?
  private let values: [String: String]
  private let bundleID: String?
  private let bundleIDInverted: Bool
  private let app: TextFilter?
  private let title: TextFilter?

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
    if let value = values["space"] {
      guard let space = Int(value), space > 0 else {
        throw IPCCommandError.invalidRequest("invalid rule space: \(value)")
      }
      self.space = space
    } else {
      space = nil
    }
    self.bundleID = values["bundle-id"] ?? values["bundle-id!"]
    self.bundleIDInverted = values["bundle-id!"] != nil
    do {
      app = try Self.textFilter(key: "app", in: values)
      title = try Self.textFilter(key: "title", in: values)
    } catch {
      throw IPCCommandError.invalidRequest("invalid rule regex: \(error.localizedDescription)")
    }
  }

  func matches(_ window: TilingWindowSnapshot) -> Bool {
    matches(bundleID, exactly: window.bundleID, inverted: bundleIDInverted)
      && app?.matches(window.app) != false
      && title?.matches(window.title) != false
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
}
