import AppKit

/// Handles IPC commands that focus, minimize, move, resize, and grid windows.
struct WindowCommandHandler {
  private let windowManager: WindowManager
  private let spaceManager: SpaceManager

  /// Create a window command handler backed by window and space managers.
  init(windowManager: WindowManager, spaceManager: SpaceManager) {
    self.windowManager = windowManager
    self.spaceManager = spaceManager
  }

  /// Dispatch a window IPC request to the matching window operation.
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
      case "--grid":
        return try grid(request)
      case "--display":
        return try display(request)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported window command: \(request.command)")
      }
    }
  }

  /// Focus the selected window, or the focused window when no selector is supplied.
  private func focus(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "focus")
    let window = try selectedWindow(selector: selector)

    guard window.focus() else {
      throw IPCCommandError.internalError("could not focus window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  /// Minimize the selected window, or the focused window when no selector is supplied.
  private func minimize(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "minimize")
    let window = try selectedWindow(selector: selector)

    guard window.minimize() else {
      throw IPCCommandError.internalError("could not minimize window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  /// Unminimize the selected window, or the focused window when no selector is supplied.
  private func unminimize(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "unminimize")
    let window = try selectedWindow(selector: selector)

    guard window.unminimize() else {
      throw IPCCommandError.internalError("could not unminimize window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  /// Move the selected window using `mode:x:y` geometry arguments.
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

  /// Resize the selected window using `mode:width:height` geometry arguments.
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

  /// Move the selected window to another display.
  private func display(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseDisplaySelection(request.args)
    guard let target = WindowDisplayTarget(argument: selection.display) else {
      throw IPCCommandError.invalidRequest("invalid window display value: \(selection.display)")
    }

    let window = try selectedWindow(selector: selection.selector)

    guard let frame = window.frame() else {
      throw IPCCommandError.internalError("could not move window to display: \(window.id)")
    }

    guard let sourceScreen = NSScreen.screen(containingLargestIntersectionWith: frame) else {
      throw IPCCommandError.internalError("could not move window to display: \(window.id)")
    }

    guard let targetScreen = target.screen(from: sourceScreen, screens: NSScreen.arrangedScreens)
    else {
      throw IPCCommandError.invalidRequest("invalid window display value: \(selection.display)")
    }

    let targetFrame = WindowDisplayTransfer(
      windowFrame: frame,
      sourceFrame: sourceScreen.axVisibleFrame,
      targetFrame: targetScreen.axVisibleFrame
    ).targetWindowFrame()

    let resized = targetFrame.size == frame.size || window.resize(to: targetFrame.size)
    let moved = window.move(to: targetFrame.origin)

    guard resized, moved else {
      throw IPCCommandError.internalError("could not move window to display: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  /// Move and resize the selected window into a grid cell span.
  private func grid(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseGeometrySelection(request.args, action: "grid")

    guard let grid = WindowGrid(argument: selection.geometry) else {
      throw IPCCommandError.invalidRequest("invalid window grid value: \(selection.geometry)")
    }

    let window = try selectedWindow(selector: selection.selector)

    guard let frame = window.frame() else {
      throw IPCCommandError.internalError("could not grid window: \(window.id)")
    }

    guard let screen = NSScreen.screen(containingLargestIntersectionWith: frame) else {
      throw IPCCommandError.internalError("could not grid window: \(window.id)")
    }

    guard let spaceID = WindowServerClient.shared.spaceIDs(containing: window.id).first else {
      throw IPCCommandError.internalError("could not grid window: \(window.id)")
    }

    let settings = spaceManager.settings(for: spaceID)
    let bounds = screen.axVisibleFrame
    let targetFrame = grid.frame(in: bounds, settings: settings)

    guard window.move(to: targetFrame.origin), window.resize(to: targetFrame.size) else {
      throw IPCCommandError.internalError("could not grid window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  /// Resolve a window selector to a concrete window.
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
      guard let windowID = WindowManager.focusedWindowID() else {
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

  /// Parse an optional single window selector argument.
  private func parseSelector(_ args: [String], action: String) throws -> String? {
    guard args.count <= 1 else {
      throw IPCCommandError.invalidRequest("invalid window \(action) arguments")
    }

    return args.first
  }

  /// Parse optional selector and required geometry arguments.
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

  /// Parse optional selector and required display arguments.
  private func parseDisplaySelection(_ args: [String]) throws -> WindowDisplaySelection {
    guard (1...2).contains(args.count) else {
      throw IPCCommandError.invalidRequest("invalid window display arguments")
    }

    if args.count == 1 {
      return WindowDisplaySelection(selector: nil, display: args[0])
    }

    return WindowDisplaySelection(selector: args[0], display: args[1])
  }

  /// Parse a geometry change in `mode:first:second` format.
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

/// Display target for moving a window.
struct WindowDisplayTarget: Equatable {
  private enum Value: Equatable {
    case next
    case previous
    case index(Int)
  }

  private let value: Value

  /// Parse a display target.
  init?(argument: String) {
    switch argument {
    case "next":
      value = .next
    case "prev", "previous":
      value = .previous
    default:
      guard let index = Int(argument), index > 0 else { return nil }
      value = .index(index)
    }
  }

  /// Resolve the target display from the available screens.
  func screen(from source: NSScreen, screens: [NSScreen]) -> NSScreen? {
    guard !screens.isEmpty else { return nil }

    switch value {
    case .next:
      guard let sourceIndex = screens.firstIndex(where: { $0.uuid == source.uuid }) else {
        return nil
      }
      return screens[(sourceIndex + 1) % screens.count]
    case .previous:
      guard let sourceIndex = screens.firstIndex(where: { $0.uuid == source.uuid }) else {
        return nil
      }
      return screens[(sourceIndex - 1 + screens.count) % screens.count]
    case .index(let index):
      let arrayIndex = index - 1
      guard screens.indices.contains(arrayIndex) else { return nil }
      return screens[arrayIndex]
    }
  }
}

extension WindowGrid {
  /// Parse a grid placement in `columns:rows:x:y:width:height` format.
  init?(argument: String) {
    let parts = argument.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

    guard
      parts.count == 6,
      let columns = Int(parts[0]),
      let rows = Int(parts[1]),
      let x = Int(parts[2]),
      let y = Int(parts[3]),
      let width = Int(parts[4]),
      let height = Int(parts[5])
    else {
      return nil
    }

    self.init(rows: rows, columns: columns, x: x, y: y, width: width, height: height)
  }
}

/// Parsed two-axis window geometry change.
private struct WindowGeometryChange {
  let mode: ChangeMode
  let first: Int
  let second: Int
}

/// Parsed window selector and geometry argument pair.
private struct WindowGeometrySelection {
  let selector: String?
  let geometry: String
}

/// Parsed window selector and display argument pair.
private struct WindowDisplaySelection {
  let selector: String?
  let display: String
}
