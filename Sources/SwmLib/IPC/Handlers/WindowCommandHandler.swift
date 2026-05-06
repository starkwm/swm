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
    case "--minimize":
      minimize(request)
    case "--unminimize":
      unminimize(request)
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
    switch selectedWindow(request, action: "focus") {
    case .window(let window):
      guard window.focus() else {
        return .failure(
          id: request.id,
          message: "could not focus window: \(window.id)",
          errorCode: .internalError
        )
      }

      return .success(id: request.id, message: "ok")

    case .failure(let response):
      return response
    }
  }

  private func minimize(_ request: IPCRequest) -> IPCResponse {
    switch selectedWindow(request, action: "minimize") {
    case .window(let window):
      guard window.minimize() else {
        return .failure(
          id: request.id,
          message: "could not minimize window: \(window.id)",
          errorCode: .internalError
        )
      }

      return .success(id: request.id, message: "ok")

    case .failure(let response):
      return response
    }
  }

  private func unminimize(_ request: IPCRequest) -> IPCResponse {
    switch selectedWindow(request, action: "unminimize") {
    case .window(let window):
      guard window.unminimize() else {
        return .failure(
          id: request.id,
          message: "could not unminimize window: \(window.id)",
          errorCode: .internalError
        )
      }

      return .success(id: request.id, message: "ok")

    case .failure(let response):
      return response
    }
  }

  private func selectedWindow(_ request: IPCRequest, action: String) -> SelectedWindow {
    guard request.args.count == 1 else {
      return .failure(
        .failure(
          id: request.id,
          message: "invalid window \(action) arguments",
          errorCode: .invalidRequest
        )
      )
    }

    switch selectedWindowID(request.args[0], request: request, action: action) {
    case .window(let windowID):
      guard let window = windowManager.window(by: windowID) else {
        return .failure(
          .failure(
            id: request.id,
            message: "window not found: \(windowID)",
            errorCode: .invalidRequest
          )
        )
      }

      return .window(window)

    case .failure(let response):
      return .failure(response)
    }
  }

  private func selectedWindowID(
    _ target: String,
    request: IPCRequest,
    action: String
  ) -> SelectedWindowID {
    guard target != "recent" else {
      guard let recentWindowID = windowManager.lastFocusedWindowID else {
        return .failure(
          .failure(
            id: request.id,
            message: "no recent window",
            errorCode: .invalidRequest
          )
        )
      }

      return .window(recentWindowID)
    }

    guard let id = UInt32(target), id != 0 else {
      return .failure(
        .failure(
          id: request.id,
          message: "invalid window \(action) target: \(target)",
          errorCode: .invalidRequest
        )
      )
    }

    let windowID = CGWindowID(id)

    return .window(windowID)
  }

  private func move(_ request: IPCRequest) -> IPCResponse {
    let selection = parseSelection(request.args)

    guard selection.arguments.count == 1 else {
      return .failure(
        id: request.id,
        message: "invalid window move arguments",
        errorCode: .invalidRequest
      )
    }

    guard let change = parseGeometryChange(selection.arguments[0]) else {
      return .failure(
        id: request.id,
        message: "invalid window move value: \(selection.arguments[0])",
        errorCode: .invalidRequest
      )
    }

    let windowID: CGWindowID
    switch selectedWindowID(selection.selector, request: request) {
    case .window(let selectedWindowID):
      windowID = selectedWindowID
    case .failure(let response):
      return response
    }

    guard let window = windowManager.window(by: windowID) else {
      return .failure(
        id: request.id,
        message: "window not found: \(windowID)",
        errorCode: .invalidRequest
      )
    }

    let moved =
      switch change.mode {
      case .absolute:
        window.move(to: CGPoint(x: change.first, y: change.second))
      case .relative:
        window.move(by: CGVector(dx: change.first, dy: change.second))
      }

    guard moved else {
      return .failure(
        id: request.id,
        message: "could not move window: \(windowID)",
        errorCode: .internalError
      )
    }

    return .success(id: request.id, message: "ok")
  }

  private func resize(_ request: IPCRequest) -> IPCResponse {
    let selection = parseSelection(request.args)

    guard selection.arguments.count == 1 else {
      return .failure(
        id: request.id,
        message: "invalid window resize arguments",
        errorCode: .invalidRequest
      )
    }

    guard let change = parseGeometryChange(selection.arguments[0]) else {
      return .failure(
        id: request.id,
        message: "invalid window resize value: \(selection.arguments[0])",
        errorCode: .invalidRequest
      )
    }

    let windowID: CGWindowID
    switch selectedWindowID(selection.selector, request: request) {
    case .window(let selectedWindowID):
      windowID = selectedWindowID
    case .failure(let response):
      return response
    }

    guard let window = windowManager.window(by: windowID) else {
      return .failure(
        id: request.id,
        message: "window not found: \(windowID)",
        errorCode: .invalidRequest
      )
    }

    let resized =
      switch change.mode {
      case .absolute:
        window.resize(to: CGSize(width: change.first, height: change.second))
      case .relative:
        window.resize(by: CGVector(dx: change.first, dy: change.second))
      }

    guard resized else {
      return .failure(
        id: request.id,
        message: "could not resize window: \(windowID)",
        errorCode: .internalError
      )
    }

    return .success(id: request.id, message: "ok")
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
        return .failure(
          .failure(
            id: request.id,
            message: "no focused window",
            errorCode: .invalidRequest
          )
        )
      }

      return .window(windowID)
    }

    switch selector {
    case "recent":
      guard let recentWindowID = windowManager.lastFocusedWindowID else {
        return .failure(
          .failure(
            id: request.id,
            message: "no recent window",
            errorCode: .invalidRequest
          )
        )
      }

      return .window(recentWindowID)

    default:
      guard let id = UInt32(selector), id != 0 else {
        return .failure(
          .failure(
            id: request.id,
            message: "invalid window selector: \(selector)",
            errorCode: .invalidRequest
          )
        )
      }

      let windowID = CGWindowID(id)

      guard windowManager.knowsWindow(withID: windowID) else {
        return .failure(
          .failure(
            id: request.id,
            message: "window not found: \(windowID)",
            errorCode: .invalidRequest
          )
        )
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

private enum SelectedWindow {
  case window(Window)
  case failure(IPCResponse)
}
