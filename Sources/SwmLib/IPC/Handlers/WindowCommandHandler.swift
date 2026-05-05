import CoreGraphics

struct WindowCommandHandler {
  private let windowManager: WindowManager

  init(windowManager: WindowManager = WindowManager(workspace: Workspace())) {
    self.windowManager = windowManager
  }

  func dispatch(_ request: IPCRequest) -> IPCResponse {
    switch request.command {
    case "--focus":
      focus(request)
    default:
      .failure(
        id: request.id,
        message: "unsupported window command: \(request.command)",
        errorCode: .unsupportedCommand
      )
    }
  }

  private func focus(_ request: IPCRequest) -> IPCResponse {
    guard request.args.count == 1 else {
      return invalid(request, "invalid window focus arguments")
    }

    let target = request.args[0]
    let windowID: CGWindowID

    switch target {
    case "recent":
      guard let recentWindowID = windowManager.lastFocusedWindowID else {
        return invalid(request, "no recent window")
      }

      windowID = recentWindowID

    default:
      guard let id = UInt32(target), id != 0 else {
        return invalid(request, "invalid window focus target: \(target)")
      }

      windowID = CGWindowID(id)

      guard windowManager.knowsWindow(withID: windowID) else {
        return invalid(request, "window not found: \(windowID)")
      }
    }

    windowManager.focusWindow(id: windowID, source: target)

    return .success(id: request.id, message: "focused window: \(windowID)")
  }

  private func invalid(_ request: IPCRequest, _ message: String) -> IPCResponse {
    .failure(id: request.id, message: message, errorCode: .invalidRequest)
  }
}
