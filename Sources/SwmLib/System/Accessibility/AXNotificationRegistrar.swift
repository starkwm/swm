import ApplicationServices

/// Registers and unregisters a fixed list of accessibility notifications.
struct AXNotificationRegistrar<Notifications: OptionSet & Sendable>: Sendable
where Notifications.RawValue == Int8 {
  /// Notification names to register, in option-bit order.
  let notifications: [String]

  /// Option set representing every expected notification.
  let allNotifications: Notifications

  /// Register notifications and update the observed option set.
  func observe(
    observedNotifications: inout Notifications,
    addNotification: (String) -> ApplicationServices.AXError,
    onFailure: (String, ApplicationServices.AXError) -> Void
  ) -> Bool {
    for (index, notification) in notifications.enumerated() {
      let result = addNotification(notification)

      if result == .success || result == .notificationAlreadyRegistered {
        observedNotifications.formUnion(Notifications(rawValue: 1 << index))
      } else {
        onFailure(notification, result)
      }
    }

    return observedNotifications.isSuperset(of: allNotifications)
  }

  /// Unregister notifications that were previously observed.
  func unobserve(
    observedNotifications: inout Notifications,
    removeNotification: (String) -> Void
  ) {
    for (index, notification) in notifications.enumerated() {
      let registeredNotification = Notifications(rawValue: 1 << index)

      guard observedNotifications.isSuperset(of: registeredNotification) else { continue }

      removeNotification(notification)
      observedNotifications.subtract(registeredNotification)
    }
  }
}
