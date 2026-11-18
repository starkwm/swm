import Foundation

public enum AccessibilityPermission {
  static let protectionOverrideVersion = OperatingSystemVersion(
    majorVersion: 27,
    minorVersion: 3,
    patchVersion: 0
  )

  public static func deniedMessage(
    osVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion,
    executablePath: String = currentExecutablePath()
  ) -> String {
    let pane =
      usesProtectionOverride(osVersion)
      ? "System & App Protection Override" : "Accessibility"
    return """
      could not access accessibility features
      Add \(executablePath) in System Settings > Privacy & Security > \(pane), then start swm again.
      If swm is already listed, remove it and add it again; an upgraded or rebuilt swm needs a new entry.
      """
  }

  static func usesProtectionOverride(_ version: OperatingSystemVersion) -> Bool {
    (version.majorVersion, version.minorVersion)
      >= (protectionOverrideVersion.majorVersion, protectionOverrideVersion.minorVersion)
  }

  public static func currentExecutablePath() -> String {
    let path = Bundle.main.executablePath ?? CommandLine.arguments[0]
    return URL(fileURLWithPath: path).resolvingSymlinksInPath().path
  }
}
