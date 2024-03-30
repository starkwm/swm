import AppKit

public struct Window {
  public var element: AXUIElement

  public init(element: AXUIElement) {
    self.element = element
  }
}
