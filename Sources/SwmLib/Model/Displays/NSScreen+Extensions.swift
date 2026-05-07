import AppKit

extension NSScreen {
  static func screen(for uuid: String?) -> NSScreen? {
    screens.first { $0.uuid == uuid }
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
}
