import Foundation

/// A user-registered command to run when a matching runtime event is emitted.
struct Signal: Equatable, Sendable {
  /// Create a signal from command-line `key=value` arguments.
  static func parseAdd(arguments: [String]) throws -> Signal {
    var event: SignalEvent?
    var action: String?
    var label: String?
    var appFilter: SignalTextFilter?
    var titleFilter: SignalTextFilter?
    var active: Bool?

    for argument in arguments {
      let item = try SignalArgument(argument)

      switch item.key {
      case "event":
        guard let value = SignalEvent(rawValue: item.value) else {
          throw IPCCommandError.invalidRequest("unsupported signal event: \(item.value)")
        }
        event = value

      case "action":
        action = item.value

      case "label":
        label = item.value

      case "app":
        appFilter = try SignalTextFilter(pattern: item.value, inverted: item.inverted)

      case "title":
        titleFilter = try SignalTextFilter(pattern: item.value, inverted: item.inverted)

      case "active":
        guard !item.inverted else {
          throw IPCCommandError.invalidRequest("invalid signal active argument")
        }
        switch item.value {
        case "yes":
          active = true
        case "no":
          active = false
        default:
          throw IPCCommandError.invalidRequest("invalid signal active value: \(item.value)")
        }

      default:
        throw IPCCommandError.invalidRequest("unsupported signal argument: \(item.rawKey)")
      }
    }

    guard let event else {
      throw IPCCommandError.invalidRequest("missing signal event")
    }

    guard let action else {
      throw IPCCommandError.invalidRequest("missing signal action")
    }

    if active != nil, !event.supportsActiveFilter {
      throw IPCCommandError.invalidRequest(
        "signal event does not support active filter: \(event.rawValue)"
      )
    }

    return Signal(
      label: label,
      event: event,
      action: action,
      appFilter: appFilter,
      titleFilter: titleFilter,
      active: active
    )
  }

  /// Optional unique user label.
  let label: String?

  /// Event name matched by this signal.
  let event: SignalEvent

  /// Shell command executed for matching events.
  let action: String

  /// Optional application-name filter.
  let appFilter: SignalTextFilter?

  /// Optional window-title filter.
  let titleFilter: SignalTextFilter?

  /// Optional active/current-state filter.
  let active: Bool?

  /// Return whether this signal should run for the payload.
  func matches(_ payload: SignalPayload) -> Bool {
    guard event == payload.event else { return false }

    if let appFilter, !appFilter.matches(payload.app) {
      return false
    }

    if let titleFilter, !titleFilter.matches(payload.title) {
      return false
    }

    if let active, payload.active != active {
      return false
    }

    return true
  }
}

/// Regex-backed text filter with optional inverted matching.
struct SignalTextFilter: Equatable, @unchecked Sendable {
  static func == (lhs: SignalTextFilter, rhs: SignalTextFilter) -> Bool {
    lhs.pattern == rhs.pattern && lhs.inverted == rhs.inverted
  }

  /// Original regular-expression pattern.
  let pattern: String

  /// Whether a regex match should reject instead of accept.
  let inverted: Bool

  private let regex: NSRegularExpression

  /// Compile a text filter.
  init(pattern: String, inverted: Bool = false) throws {
    do {
      regex = try NSRegularExpression(pattern: pattern)
    } catch {
      throw IPCCommandError.invalidRequest("invalid signal regex: \(pattern)")
    }

    self.pattern = pattern
    self.inverted = inverted
  }

  /// Return whether the optional value satisfies the filter.
  func matches(_ value: String?) -> Bool {
    guard let value else { return false }

    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    let matched = regex.firstMatch(in: value, range: range) != nil

    return inverted ? !matched : matched
  }
}

/// Parsed `key=value` or `key!=value` signal argument.
private struct SignalArgument {
  let rawKey: String
  let key: String
  let value: String
  let inverted: Bool

  init(_ argument: String) throws {
    if let range = argument.range(of: "!=") {
      rawKey = String(argument[..<range.lowerBound]) + "!"
      key = String(argument[..<range.lowerBound])
      value = String(argument[range.upperBound...])
      inverted = true
    } else if let range = argument.range(of: "=") {
      rawKey = String(argument[..<range.lowerBound])
      key = rawKey
      value = String(argument[range.upperBound...])
      inverted = false
    } else {
      throw IPCCommandError.invalidRequest("invalid signal argument: \(argument)")
    }

    guard !key.isEmpty, !value.isEmpty else {
      throw IPCCommandError.invalidRequest("invalid signal argument: \(argument)")
    }
  }
}
