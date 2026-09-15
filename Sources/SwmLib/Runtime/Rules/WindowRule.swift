import Foundation

/// Window filters and optional management and placement actions.
struct WindowRule: Encodable {
  /// Parse and validate a registration before changing runtime state.
  static func parse(arguments: [String]) throws -> WindowRule {
    var values = [String: String]()
    for argument in arguments {
      guard let separator = argument.firstIndex(of: "=") else {
        throw IPCCommandError.invalidRequest("invalid rule argument: \(argument)")
      }
      let key = String(argument[..<separator])
      let value = String(argument[argument.index(after: separator)...])
      guard
        ["label", "app", "app!", "title", "title!", "bundle-id", "manage", "grid", "display"]
          .contains(key),
        !value.isEmpty
      else { throw IPCCommandError.invalidRequest("invalid rule argument: \(argument)") }
      let base = key.hasSuffix("!") ? String(key.dropLast()) : key
      guard values[base] == nil, values[base + "!"] == nil else {
        throw IPCCommandError.invalidRequest("duplicate rule argument: \(base)")
      }
      values[key] = value
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
  let bundleID: String?
  private let values: [String: String]
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
    self.bundleID = values["bundle-id"]
    do {
      app = try (values["app"] ?? values["app!"]).map { try NSRegularExpression(pattern: $0) }
      title = try (values["title"] ?? values["title!"]).map { try NSRegularExpression(pattern: $0) }
    } catch {
      throw IPCCommandError.invalidRequest("invalid rule regex: \(error.localizedDescription)")
    }
  }

  func matches(_ window: TilingWindowSnapshot) -> Bool {
    if let bundleID, bundleID != window.bundleID { return false }
    return matches(app, value: window.app, inverted: values["app!"] != nil)
      && matches(title, value: window.title, inverted: values["title!"] != nil)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(values)
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
