import AppKit

extension NSScreen {
  static var arrangedScreens: [NSScreen] {
    screens.sorted { lhs, rhs in
      if lhs.frame.minX != rhs.frame.minX {
        return lhs.frame.minX < rhs.frame.minX
      }

      return lhs.frame.maxY > rhs.frame.maxY
    }
  }

  static func screen(for uuid: String?) -> NSScreen? {
    screens.first { $0.uuid == uuid }
  }

  static func screen(containingLargestIntersectionWith frame: CGRect) -> NSScreen? {
    screens.largestIntersection(with: frame, frame: \.axVisibleFrame)
  }

  var id: UInt32? {
    let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    return number?.uint32Value
  }

  var uuid: String {
    guard let id, let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else {
      return ""
    }

    return (CFUUIDCreateString(nil, uuid) as String?) ?? ""
  }

  var axFrame: CGRect {
    accessibilityFrame(for: frame)
  }

  var axVisibleFrame: CGRect {
    accessibilityFrame(
      for: ScreenGeometry.visibleFrame(
        visibleFrame,
        in: frame,
        hiddenDockEdge: DockPreferences.hiddenDockEdge()
      )
    )
  }

  private func accessibilityFrame(for frame: CGRect) -> CGRect {
    guard let primaryFrame = NSScreen.screens.first?.frame else {
      return frame
    }

    return ScreenGeometry.accessibilityFrame(frame, primaryFrame: primaryFrame)
  }
}
