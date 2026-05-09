import AppKit

struct WindowCommandHandler {
  private let windowManager: WindowManager
  private let spaceManager: SpaceManager

  init(windowManager: WindowManager, spaceManager: SpaceManager) {
    self.windowManager = windowManager
    self.spaceManager = spaceManager
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
      case "--grid":
        return try grid(request)
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
      guard let windowID = windowManager.focusedWindowID() else {
        throw IPCCommandError.invalidRequest("no focused window")
      }

      guard let window = windowManager.focusedWindow(by: windowID) else {
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

struct WindowGrid: Equatable {
  private let rows: Int
  private let columns: Int
  private let x: Int
  private let y: Int
  private let width: Int
  private let height: Int

  init?(
    rows: Int,
    columns: Int,
    x: Int,
    y: Int,
    width: Int,
    height: Int
  ) {
    guard rows > 0, columns > 0 else { return nil }

    let x = min(max(0, x), columns - 1)
    let y = min(max(0, y), rows - 1)
    let width = min(max(1, width), columns - x)
    let height = min(max(1, height), rows - y)

    self.rows = rows
    self.columns = columns
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

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

  func frame(in bounds: CGRect, settings: SpaceSettings) -> CGRect {
    let padding = settings.paddingEnabled ? settings.padding : .zero
    let gap = settings.gapEnabled ? CGFloat(settings.gap) : 0

    var bounds = bounds
    bounds.origin.x += CGFloat(padding.left)
    bounds.size.width -= CGFloat(padding.left + padding.right)
    bounds.origin.y += CGFloat(padding.top)
    bounds.size.height -= CGFloat(padding.top + padding.bottom)

    if x > 0 {
      bounds.origin.x += gap
      bounds.size.width -= gap
    }

    if y > 0 {
      bounds.origin.y += gap
      bounds.size.height -= gap
    }

    if columns > x + width {
      bounds.size.width -= gap
    }

    if rows > y + height {
      bounds.size.height -= gap
    }

    let cellWidth = bounds.width / CGFloat(columns)
    let cellHeight = bounds.height / CGFloat(rows)

    return CGRect(
      x: bounds.minX + bounds.width - cellWidth * CGFloat(columns - x),
      y: bounds.minY + bounds.height - cellHeight * CGFloat(rows - y),
      width: cellWidth * CGFloat(width),
      height: cellHeight * CGFloat(height)
    )
  }
}
