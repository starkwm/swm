import CoreFoundation

/// Screen edge that holds the Dock.
enum DockEdge: String {
  case bottom
  case left
  case right
}

/// The Dock settings that change how much of a screen windows may use.
enum DockPreferences {
  /// The Dock's edge when it hides automatically, or nil when it always shows.
  static func hiddenDockEdge() -> DockEdge? {
    let domain = "com.apple.dock" as CFString
    CFPreferencesAppSynchronize(domain)
    guard CFPreferencesGetAppBooleanValue("autohide" as CFString, domain, nil) else {
      return nil
    }

    let orientation = CFPreferencesCopyAppValue("orientation" as CFString, domain) as? String
    return orientation.flatMap(DockEdge.init(rawValue:)) ?? .bottom
  }
}
