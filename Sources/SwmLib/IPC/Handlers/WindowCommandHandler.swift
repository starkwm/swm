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
    case "--move":
      move(request)
    case "--resize":
      resize(request)
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

  private func move(_ request: IPCRequest) -> IPCResponse {
    let selection = parseSelection(request.args)

    guard selection.arguments.count == 1 else {
      return invalid(request, "invalid window move arguments")
    }

    let windowID: CGWindowID
    switch selectedWindowID(selection.selector, request: request) {
    case .window(let id):
      windowID = id
    case .failure(let response):
      return response
    }

    guard let change = parseGeometryChange(selection.arguments[0]) else {
      return invalid(request, "invalid window move value: \(selection.arguments[0])")
    }

    windowManager.moveWindow(id: windowID, mode: change.mode, x: change.first, y: change.second)

    return .success(id: request.id, message: "moved window: \(windowID)")
  }

  private func resize(_ request: IPCRequest) -> IPCResponse {
    let selection = parseSelection(request.args)

    guard selection.arguments.count == 1 else {
      return invalid(request, "invalid window resize arguments")
    }

    let windowID: CGWindowID
    switch selectedWindowID(selection.selector, request: request) {
    case .window(let id):
      windowID = id
    case .failure(let response):
      return response
    }

    guard let change = parseGeometryChange(selection.arguments[0]) else {
      return invalid(request, "invalid window resize value: \(selection.arguments[0])")
    }

    windowManager.resizeWindow(
      id: windowID,
      mode: change.mode,
      width: change.first,
      height: change.second
    )

    return .success(id: request.id, message: "resized window: \(windowID)")
  }

  private func parseSelection(_ args: [String]) -> WindowSelection {
    guard args.count >= 2, args[0] == "--window" else {
      return WindowSelection(selector: nil, arguments: args)
    }

    return WindowSelection(selector: args[1], arguments: Array(args.dropFirst(2)))
  }

  private func selectedWindowID(
    _ selector: String?,
    request: IPCRequest
  ) -> SelectedWindowID {
    guard let selector else {
      guard let windowID = windowManager.currentFocusedWindowID else {
        return .failure(invalid(request, "no focused window"))
      }

      return .window(windowID)
    }

    switch selector {
    case "recent":
      guard let recentWindowID = windowManager.lastFocusedWindowID else {
        return .failure(invalid(request, "no recent window"))
      }

      return .window(recentWindowID)

    default:
      guard let id = UInt32(selector), id != 0 else {
        return .failure(invalid(request, "invalid window selector: \(selector)"))
      }

      let windowID = CGWindowID(id)

      guard windowManager.knowsWindow(withID: windowID) else {
        return .failure(invalid(request, "window not found: \(windowID)"))
      }

      return .window(windowID)
    }
  }

  private func parseGeometryChange(_ argument: String) -> WindowGeometryChange? {
    let parts = argument.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

    guard
      parts.count == 3,
      let mode = ChangeMode(rawValue: parts[0]),
      let first = Int(parts[1]),
      let second = Int(parts[2])
    else {
      return nil
    }

    return WindowGeometryChange(mode: mode, first: first, second: second)
  }

  private func invalid(_ request: IPCRequest, _ message: String) -> IPCResponse {
    .failure(id: request.id, message: message, errorCode: .invalidRequest)
  }
}

private struct WindowGeometryChange {
  let mode: ChangeMode
  let first: Int
  let second: Int
}

private struct WindowSelection {
  let selector: String?
  let arguments: [String]
}

private enum SelectedWindowID {
  case window(CGWindowID)
  case failure(IPCResponse)
}
