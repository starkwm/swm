import AppKit

extension NSScreen {
  static func screen(for id: String) -> NSScreen? {
    screens.first { $0.id == id }
  }

  var id: String {
    guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    else { return "" }

    let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value).takeRetainedValue()
    return CFUUIDCreateString(nil, uuid) as String
  }
}
