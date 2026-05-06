import CoreGraphics

struct WindowCommandHandler {
  private let windowManager: WindowManager

  init(windowManager: WindowManager) {
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
    let selector = try parseSelector(request.args, action: "focus")
    let window = try selectedWindow(selector: selector)

    guard window.focus() else {
      throw IPCCommandError.internalError("could not focus window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  private func minimize(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "minimize")
    let window = try selectedWindow(selector: selector)

    guard window.minimize() else {
      throw IPCCommandError.internalError("could not minimize window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  private func unminimize(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "unminimize")
    let window = try selectedWindow(selector: selector)

    guard window.unminimize() else {
      throw IPCCommandError.internalError("could not unminimize window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  private func move(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseGeometrySelection(request.args, action: "move")

    guard let change = parseGeometryChange(selection.geometry) else {
      throw IPCCommandError.invalidRequest("invalid window move value: \(selection.geometry)")
    }

    let window = try selectedWindow(selector: selection.selector)

    let moved =
      switch change.mode {
      case .absolute:
        window.move(to: CGPoint(x: change.first, y: change.second))
      case .relative:
        window.move(by: CGVector(dx: change.first, dy: change.second))
      }

    guard moved else {
      throw IPCCommandError.internalError("could not move window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  private func resize(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseGeometrySelection(request.args, action: "resize")

    guard let change = parseGeometryChange(selection.geometry) else {
      throw IPCCommandError.invalidRequest("invalid window resize value: \(selection.geometry)")
    }

    let window = try selectedWindow(selector: selection.selector)

    let resized =
      switch change.mode {
      case .absolute:
        window.resize(to: CGSize(width: change.first, height: change.second))
      case .relative:
        window.resize(by: CGVector(dx: change.first, dy: change.second))
      }

    guard resized else {
      throw IPCCommandError.internalError("could not resize window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  private func selectedWindow(selector: String?) throws -> Window {
    let windowID: CGWindowID

    if let selector {
      switch selector {
      case "recent":
        guard let recentWindowID = windowManager.lastFocusedWindowID else {
          throw IPCCommandError.invalidRequest("no recent window")
        }

        windowID = recentWindowID

      default:
        guard let id = UInt32(selector), id != 0 else {
          throw IPCCommandError.invalidRequest("invalid window selector: \(selector)")
        }

        windowID = CGWindowID(id)
      }
    } else {
      guard let windowID = windowManager.currentFocusedWindowID else {
        throw IPCCommandError.invalidRequest("no focused window")
      }

      guard let window = windowManager.window(by: windowID) else {
        throw IPCCommandError.invalidRequest("window not found: \(windowID)")
      }

      return window
    }

    guard let window = windowManager.window(by: windowID) else {
      throw IPCCommandError.invalidRequest("window not found: \(windowID)")
    }

    return window
  }

  private func parseSelector(_ args: [String], action: String) throws -> String? {
    guard args.count <= 1 else {
      throw IPCCommandError.invalidRequest("invalid window \(action) arguments")
    }

    return args.first
  }

  private func parseGeometrySelection(
    _ args: [String],
    action: String
  ) throws -> WindowGeometrySelection {
    guard (1...2).contains(args.count) else {
      throw IPCCommandError.invalidRequest("invalid window \(action) arguments")
    }

    if args.count == 1 {
      return WindowGeometrySelection(selector: nil, geometry: args[0])
    }

    return WindowGeometrySelection(selector: args[0], geometry: args[1])
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

private struct WindowGeometrySelection {
  let selector: String?
  let geometry: String
}
