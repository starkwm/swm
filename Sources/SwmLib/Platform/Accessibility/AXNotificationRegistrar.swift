import ApplicationServices

struct AXNotificationRegistrar: Sendable {
  let notifications: [String]

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
        if result == .cannotComplete { break }
      }
    }

    return observedNotifications.isSuperset(of: notifications)
  }

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
