import AppKit

public struct Application {
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
}
