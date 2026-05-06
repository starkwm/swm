import CoreGraphics

struct WindowCommandHandler {
  private let windowManager: WindowManager

  init(windowManager: WindowManager = WindowManager(workspace: Workspace())) {
    self.windowManager = windowManager
  }

  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "--focus":
        return try focus(request)
      case "--minimize":
        return try minimize(request)
      case "--unminimize":
        return try unminimize(request)
      case "--move":
        return try move(request)
      case "--resize":
        return try resize(request)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported window command: \(request.command)")
      }
    }
  }

  private func focus(_ request: IPCRequest) throws -> IPCResponse {
    let window = try selectedWindow(request, action: "focus")

    guard window.focus() else {
      throw IPCCommandError.internalError("could not focus window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  private func minimize(_ request: IPCRequest) throws -> IPCResponse {
    let window = try selectedWindow(request, action: "minimize")

    guard window.minimize() else {
      throw IPCCommandError.internalError("could not minimize window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  private func unminimize(_ request: IPCRequest) throws -> IPCResponse {
    let window = try selectedWindow(request, action: "unminimize")

    guard window.unminimize() else {
      throw IPCCommandError.internalError("could not unminimize window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  private func selectedWindow(_ request: IPCRequest, action: String) throws -> Window {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid window \(action) arguments")
    }

    let windowID = try selectedWindowID(request.args[0], action: action)

    guard let window = windowManager.window(by: windowID) else {
      throw IPCCommandError.invalidRequest("window not found: \(windowID)")
    }

    return window
  }

  private func selectedWindowID(
    _ target: String,
    action: String
  ) throws -> CGWindowID {
    guard target != "recent" else {
      guard let recentWindowID = windowManager.lastFocusedWindowID else {
        throw IPCCommandError.invalidRequest("no recent window")
      }

      return recentWindowID
    }

    guard let id = UInt32(target), id != 0 else {
      throw IPCCommandError.invalidRequest("invalid window \(action) target: \(target)")
    }

    let windowID = CGWindowID(id)

    return windowID
  }

  private func move(_ request: IPCRequest) throws -> IPCResponse {
    let selection = parseSelection(request.args)

    guard selection.arguments.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid window move arguments")
    }

    guard let change = parseGeometryChange(selection.arguments[0]) else {
      throw IPCCommandError.invalidRequest("invalid window move value: \(selection.arguments[0])")
    }

    let windowID = try selectedWindowID(selection.selector)

    guard let window = windowManager.window(by: windowID) else {
      throw IPCCommandError.invalidRequest("window not found: \(windowID)")
    }

    let moved =
      switch change.mode {
      case .absolute:
        window.move(to: CGPoint(x: change.first, y: change.second))
      case .relative:
        window.move(by: CGVector(dx: change.first, dy: change.second))
      }

    guard moved else {
      throw IPCCommandError.internalError("could not move window: \(windowID)")
    }

    return .success(id: request.id, message: "ok")
  }

  private func resize(_ request: IPCRequest) throws -> IPCResponse {
    let selection = parseSelection(request.args)

    guard selection.arguments.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid window resize arguments")
    }

    guard let change = parseGeometryChange(selection.arguments[0]) else {
      throw IPCCommandError.invalidRequest("invalid window resize value: \(selection.arguments[0])")
    }

    let windowID = try selectedWindowID(selection.selector)

    guard let window = windowManager.window(by: windowID) else {
      throw IPCCommandError.invalidRequest("window not found: \(windowID)")
    }

    let resized =
      switch change.mode {
      case .absolute:
        window.resize(to: CGSize(width: change.first, height: change.second))
      case .relative:
        window.resize(by: CGVector(dx: change.first, dy: change.second))
      }

    guard resized else {
      throw IPCCommandError.internalError("could not resize window: \(windowID)")
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
    _ selector: String?
  ) throws -> CGWindowID {
    guard let selector else {
      guard let windowID = windowManager.currentFocusedWindowID else {
        throw IPCCommandError.invalidRequest("no focused window")
      }

      return windowID
    }

    switch selector {
    case "recent":
      guard let recentWindowID = windowManager.lastFocusedWindowID else {
        throw IPCCommandError.invalidRequest("no recent window")
      }

      return recentWindowID

    default:
      guard let id = UInt32(selector), id != 0 else {
        throw IPCCommandError.invalidRequest("invalid window selector: \(selector)")
      }

      let windowID = CGWindowID(id)

      guard windowManager.knowsWindow(withID: windowID) else {
        throw IPCCommandError.invalidRequest("window not found: \(windowID)")
      }

      return windowID
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
