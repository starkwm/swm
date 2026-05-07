import AppKit

extension NSScreen {
  static func screen(for uuid: String?) -> NSScreen? {
    screens.first { $0.uuid == uuid }
  }

  static func screen(containingLargestIntersectionWith frame: CGRect) -> NSScreen? {
    screens.max { lhs, rhs in
      frame.intersection(lhs.axVisibleFrame).area
        < frame.intersection(rhs.axVisibleFrame).area
    }
  }

  var id: UInt32? {
    let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    return number?.uint32Value
  }

  var uuid: String {
    guard let id = id else { return "" }

    let uuid = CGDisplayCreateUUIDFromDisplayID(id).takeRetainedValue()
    return CFUUIDCreateString(nil, uuid) as String
  }

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
  fileprivate var area: CGFloat {
    width * height
  }
}
