import ApplicationServices

/// Registers and unregisters a fixed list of accessibility notifications.
struct AXNotificationRegistrar: Sendable {
  /// Notification names to register.
  let notifications: [String]

  /// Register notifications and update the observed-name set.
  func observe(
    observedNotifications: inout Set<String>,
    addNotification: (String) -> ApplicationServices.AXError,
    onFailure: (String, ApplicationServices.AXError) -> Void
  ) -> Bool {
    for notification in notifications {
      let result = addNotification(notification)

      if result == .success || result == .notificationAlreadyRegistered {
        observedNotifications.insert(notification)
      } else {
        onFailure(notification, result)
      }
    }

    return observedNotifications.isSuperset(of: notifications)
  }

  /// Unregister notifications that were previously observed.
  func unobserve(
    observedNotifications: inout Set<String>,
    removeNotification: (String) -> Void
  ) {
    for notification in notifications where observedNotifications.contains(notification) {

      removeNotification(notification)
      observedNotifications.remove(notification)
    }
  }
}
