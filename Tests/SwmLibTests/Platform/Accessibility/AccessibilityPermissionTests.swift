import Foundation
import Testing

@testable import SwmLib

@Suite("AccessibilityPermission")
struct AccessibilityPermissionTests {
  private let path = "/opt/homebrew/Cellar/swm/0.0.32/bin/swm"

  @Test(
    "deniedMessage: macOS 27.3 and later point to System & App Protection Override",
    arguments: [(27, 3, 0), (27, 4, 1), (28, 0, 0)]
  )
  func deniedMessagePointsToProtectionOverride(major: Int, minor: Int, patch: Int) {
    let message = AccessibilityPermission.deniedMessage(
      osVersion: OperatingSystemVersion(
        majorVersion: major,
        minorVersion: minor,
        patchVersion: patch
      ),
      executablePath: path
    )

    #expect(
      message.contains(
        "Add \(path) in System Settings > Privacy & Security > System & App Protection Override"
      )
    )
  }

  @Test(
    "deniedMessage: earlier macOS versions point to Accessibility",
    arguments: [(26, 0, 0), (27, 2, 9)]
  )
  func deniedMessagePointsToAccessibility(major: Int, minor: Int, patch: Int) {
    let message = AccessibilityPermission.deniedMessage(
      osVersion: OperatingSystemVersion(
        majorVersion: major,
        minorVersion: minor,
        patchVersion: patch
      ),
      executablePath: path
    )

    #expect(
      message.contains("Add \(path) in System Settings > Privacy & Security > Accessibility,")
    )
  }
}
