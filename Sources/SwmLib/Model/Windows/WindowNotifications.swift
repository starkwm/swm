import Carbon

/// Accessibility notifications observed for an individual window.
struct WindowNotifications: OptionSet, Sendable {
  /// Observe window destruction.
  static let windowDestroyed = WindowNotifications(rawValue: 1 << 0)

  /// Observe window minimization.
  static let windowMinimized = WindowNotifications(rawValue: 1 << 1)

  /// Observe restoration from a minimized state.
  static let windowDeminimized = WindowNotifications(rawValue: 1 << 2)

  /// All window-level notifications currently used by swm.
  static let all: WindowNotifications = [
    .windowDestroyed,
    .windowMinimized,
    .windowDeminimized,
  ]

  /// Backing option-set bit field.
  let rawValue: Int8
}

/// Accessibility notification names matching `WindowNotifications`.
let windowNotifications = [
  kAXUIElementDestroyedNotification,
  kAXWindowMiniaturizedNotification,
  kAXWindowDeminiaturizedNotification,
]
