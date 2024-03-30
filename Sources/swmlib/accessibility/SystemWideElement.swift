import AppKit

public var systemWideElement = SystemWideElement()

public struct SystemWideElement {
  var systemWideElement: AXUIElement

  fileprivate init() {
    systemWideElement = AXUIElementCreateSystemWide()
  }
}
