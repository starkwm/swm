import AppKit

extension NSScreen {
  /// Return the screen with the given Core Graphics display UUID.
  static func screen(for uuid: String?) -> NSScreen? {
    screens.first { $0.uuid == uuid }
  }

  /// Return the screen whose accessibility-visible frame overlaps a frame the most.
  static func screen(containingLargestIntersectionWith frame: CGRect) -> NSScreen? {
    screens.max { lhs, rhs in
      frame.intersection(lhs.axVisibleFrame).area
        < frame.intersection(rhs.axVisibleFrame).area
    }
  }

  /// Core Graphics display ID for this screen.
  var id: UInt32? {
    let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    return number?.uint32Value
  }

  /// Core Graphics display UUID string for this screen.
  var uuid: String {
    guard let id = id else { return "" }

    let uuid = CGDisplayCreateUUIDFromDisplayID(id).takeRetainedValue()
    return CFUUIDCreateString(nil, uuid) as String
  }

  /// Visible frame converted to the coordinate space used by accessibility APIs.
  var axVisibleFrame: CGRect {
    guard let mainFrame = NSScreen.screens.map(\.frame).max(by: { $0.maxY < $1.maxY }) else {
      return visibleFrame
    }

    return CGRect(
      x: visibleFrame.origin.x,
      y: mainFrame.maxY - visibleFrame.maxY,
      width: visibleFrame.width,
      height: visibleFrame.height
    )
  }
}

extension CGRect {
  /// Rectangle area.
  fileprivate var area: CGFloat {
    width * height
  }
}
