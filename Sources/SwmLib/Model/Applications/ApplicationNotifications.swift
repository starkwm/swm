import ApplicationServices

/// Accessibility notifications observed for an application.
struct ApplicationNotifications: OptionSet, Sendable {
  /// Observe newly created windows.
  static let windowCreated = ApplicationNotifications(rawValue: 1 << 0)

  /// Observe focused-window changes.
  static let windowFocused = ApplicationNotifications(rawValue: 1 << 1)

  /// Observe window movement.
  static let windowMoved = ApplicationNotifications(rawValue: 1 << 2)

  /// Observe window resizing.
  static let windowResized = ApplicationNotifications(rawValue: 1 << 3)

  /// All application-level notifications currently used by swm.
  static let all: ApplicationNotifications = [
    .windowCreated,
    .windowFocused,
    .windowMoved,
    .windowResized,
  ]

  /// Backing option-set bit field.
  let rawValue: Int8
}

/// Accessibility notification names matching `ApplicationNotifications`.
let applicationNotifications = [
  kAXCreatedNotification,
  kAXFocusedWindowChangedNotification,
  kAXWindowMovedNotification,
  kAXWindowResizedNotification,
]
