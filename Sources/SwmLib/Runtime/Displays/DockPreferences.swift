import CoreFoundation

enum DockEdge: String {
  case bottom
  case left
  case right
}

enum DockPreferences {
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
