import Foundation

struct Signal: Equatable, Sendable {
  static func parseAdd(arguments: [String]) throws -> Signal {
    var event: SignalEvent?
    var action: String?
    var label: String?
    var appFilter: TextFilter?
    var titleFilter: TextFilter?
    var active: Bool?

    for argument in arguments {
      guard let item = KeyValueArgument(argument) else {
        throw IPCCommandError.invalidRequest("invalid signal argument: \(argument)")
      }
      guard !item.inverted || item.key == "app" || item.key == "title" else {
        throw IPCCommandError.invalidRequest("unsupported signal argument: \(item.rawKey)")
      }

      switch item.key {
      case "event":
        guard let value = SignalEvent(rawValue: item.value) else {
          throw IPCCommandError.invalidRequest(
            "unsupported signal event: \(item.value); expected one of "
              + SignalEvent.allCases.map(\.rawValue).joined(separator: ", ")
          )
        }
        event = value

      case "action":
        action = item.value

      case "label":
        guard Int(item.value) == nil else {
          throw IPCCommandError.invalidRequest("signal label must not be an integer")
        }
        label = item.value

      case "app":
        appFilter = try textFilter(item)

      case "title":
        titleFilter = try textFilter(item)

      case "active":
        switch item.value {
        case "on":
          active = true
        case "off":
          active = false
        default:
          throw IPCCommandError.invalidRequest("invalid signal active value: \(item.value)")
        }

      default:
        throw IPCCommandError.invalidRequest(
          "unsupported signal argument: \(item.rawKey); expected event, action, label, app, title,"
            + " or active"
        )
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

  private static func textFilter(_ item: KeyValueArgument) throws -> TextFilter {
    do {
      return try TextFilter(pattern: item.value, inverted: item.inverted)
    } catch {
      throw IPCCommandError.invalidRequest("invalid signal regex: \(item.value)")
    }
  }

  let label: String?

  let event: SignalEvent

  let action: String

  let appFilter: TextFilter?

  let titleFilter: TextFilter?

  let active: Bool?

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
