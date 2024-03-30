import AppKit

public struct Application {
  public static func all() -> [Application] {
    NSWorkspace.shared.runningApplications.map { Application(app: $0) }
  }

  private var element: AXUIElement

  private var app: NSRunningApplication

  public init(pid: pid_t) {
    element = AXUIElementCreateApplication(pid)
    app = NSRunningApplication(processIdentifier: pid)!
  }

  public init(app: NSRunningApplication) {
    element = AXUIElementCreateApplication(app.processIdentifier)
    self.app = app
  }

  public func windows() -> [Window] {
    var values: CFArray?
    let result = AXUIElementCopyAttributeValues(element, kAXWindowsAttribute as CFString, 0, 100, &values)

    if result != .success {
      return []
    }

    guard let elements = values as? [AXUIElement] else {
      return []
    }

    return elements.map { Window(element: $0) }
  }
}
