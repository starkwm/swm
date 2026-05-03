import ApplicationServices

struct AXNotificationRegistrar<Notifications: OptionSet & Sendable>: Sendable
where Notifications.RawValue == Int8 {
  let notifications: [String]
  let allNotifications: Notifications

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
