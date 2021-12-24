import AppKit

public struct Application {
    public var element: AXUIElement

    public init(pid: pid_t) {
        element = AXUIElementCreateApplication(pid)
    }
}
