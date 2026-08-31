import AppKit

/// Handles IPC commands that focus, minimize, move, resize, tile, and grid windows.
@MainActor
struct WindowCommandHandler {
  private let windowManager: WindowManager
  private let spaceManager: SpaceManager
  private let tilingManager: TilingManager

  /// Create a window command handler backed by window, Space, and tiling managers.
  init(
    windowManager: WindowManager,
    spaceManager: SpaceManager,
    tilingManager: TilingManager
  ) {
    self.windowManager = windowManager
    self.spaceManager = spaceManager
    self.tilingManager = tilingManager
  }

  /// Dispatch a window IPC request to the matching window operation.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "--focus":
        return try focus(request)
      case "--minimize":
        return try performWindowAction(request, action: "minimize") { $0.minimize() }
      case "--unminimize":
        return try performWindowAction(request, action: "unminimize") { $0.unminimize() }
      case "--layout":
        return try layout(request)
      case "--cycle":
        return try cycle(request)
      case "--swap":
        return try swap(request)
      case "--swap-cycle":
        return try swapCycle(request)
      case "--swap-with-master":
        return try swapWithMaster(request)
      case "--split-ratio":
        return try splitRatio(request)
      case "--toggle-split":
        return try toggleSplit(request)
      case "--move":
        return try performGeometryAction(request, action: "move") { window, change in
          switch change.mode {
          case .absolute:
            window.move(to: CGPoint(x: change.first, y: change.second))
          case .relative:
            window.move(by: CGVector(dx: change.first, dy: change.second))
          }
        }
      case "--resize":
        return try performGeometryAction(request, action: "resize") { window, change in
          switch change.mode {
          case .absolute:
            window.resize(to: CGSize(width: change.first, height: change.second))
          case .relative:
            window.resize(by: CGVector(dx: change.first, dy: change.second))
          }
        }
      case "--grid":
        return try grid(request)
      case "--display":
        return try display(request)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported window command: \(request.command)")
      }
    }
  }

  /// Focus a selected window or the closest visible window in a direction.
  private func focus(_ request: IPCRequest) throws -> IPCResponse {
    guard let target = WindowFocusTarget(arguments: request.args) else {
      throw IPCCommandError.invalidRequest("invalid window focus arguments")
    }

    let window: Window
    switch target {
    case .selected(let selector):
      window = try selectedWindow(selector: selector)
    case .direction(let direction):
      let sourceWindow = try selectedWindow(selector: nil)
      guard let directionalWindow = directionalWindow(from: sourceWindow, in: direction) else {
        throw IPCCommandError.invalidRequest(
          "window has no focusable neighbour in direction: \(direction.rawValue)"
        )
      }
      window = directionalWindow
    }

    guard window.focus() else {
      throw IPCCommandError.internalError("could not focus window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  /// Set the selected window's floating or tiled participation.
  private func layout(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseValueSelection(request.args, action: "layout")
    guard let layout = WindowLayoutSelection(rawValue: selection.value) else {
      throw IPCCommandError.invalidRequest("invalid window layout: \(selection.value)")
    }
    let window = try selectedWindow(selector: selection.selector)
    guard tilingManager.setWindowLayout(layout, for: window.id) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for window: \(window.id)")
    }
    return .success(id: request.id, message: layout.rawValue)
  }

  /// Focus the next available window in stable layout order.
  private func cycle(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid window cycle arguments")
    }
    guard let direction = CycleDirection(rawValue: request.args[0]) else {
      throw IPCCommandError.invalidRequest("invalid window cycle direction: \(request.args[0])")
    }
    let window = try selectedWindow(selector: nil)
    guard let cycledWindowID = tilingManager.cycledWindowID(from: window.id, in: direction),
      let cycledWindow = windowManager.window(by: cycledWindowID)
    else {
      throw IPCCommandError.invalidRequest("window has no cycle neighbour: \(window.id)")
    }
    guard cycledWindow.focus() else {
      throw IPCCommandError.internalError("could not focus window: \(cycledWindow.id)")
    }
    return .success(id: request.id, message: "ok")
  }

  /// Swap the selected window with its neighbour in a direction.
  private func swap(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseValueSelection(request.args, action: "swap")
    guard let direction = CardinalDirection(rawValue: selection.value) else {
      throw IPCCommandError.invalidRequest("invalid window swap direction: \(selection.value)")
    }
    let window = try selectedWindow(selector: selection.selector)
    guard tilingManager.swapWindow(window.id, in: direction) else {
      throw IPCCommandError.invalidRequest(
        "window has no swappable neighbour in direction: \(direction.rawValue)"
      )
    }
    return .success(id: request.id, message: "ok")
  }

  /// Swap the focused tiled window with its neighbour in stable layout order.
  private func swapCycle(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid window swap-cycle arguments")
    }
    guard let direction = CycleDirection(rawValue: request.args[0]) else {
      throw IPCCommandError.invalidRequest(
        "invalid window swap-cycle direction: \(request.args[0])"
      )
    }
    let window = try selectedWindow(selector: nil)
    guard tilingManager.swapWindowInOrder(window.id, in: direction) else {
      throw IPCCommandError.invalidRequest("window has no swap-cycle neighbour: \(window.id)")
    }
    return .success(id: request.id, message: "ok")
  }

  /// Swap the selected tiled window with the master pane.
  private func swapWithMaster(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "swap-with-master")
    let window = try selectedWindow(selector: selector)
    guard tilingManager.swapWindowWithMaster(window.id) else {
      throw IPCCommandError.invalidRequest("window is not in a master layout: \(window.id)")
    }
    return .success(id: request.id, message: "ok")
  }

  /// Set or adjust the selected window's nearest dwindle split ratio.
  private func splitRatio(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseValueSelection(request.args, action: "split-ratio")
    guard let change = LayoutCommandParser.ratioChange(from: selection.value) else {
      throw IPCCommandError.invalidRequest("invalid window split-ratio value: \(selection.value)")
    }
    let window = try selectedWindow(selector: selection.selector)
    guard tilingManager.changeDwindleSplitRatio(change, for: window.id) != nil else {
      throw IPCCommandError.invalidRequest("window has no dwindle split: \(window.id)")
    }
    return .success(id: request.id, message: "ok")
  }

  /// Toggle and retain the selected window's nearest dwindle split direction.
  private func toggleSplit(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "toggle-split")
    let window = try selectedWindow(selector: selector)
    guard tilingManager.toggleDwindleSplit(for: window.id) else {
      throw IPCCommandError.invalidRequest(
        "window has no retained dwindle split to toggle: \(window.id)"
      )
    }
    return .success(id: request.id, message: "ok")
  }

  /// Perform an action on a selected window.
  private func performWindowAction(
    _ request: IPCRequest,
    action: String,
    operation: (Window) -> Bool
  ) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: action)
    let window = try selectedWindow(selector: selector)

    guard operation(window) else {
      throw IPCCommandError.internalError("could not \(action) window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  /// Perform a two-axis geometry action on a selected window.
  private func performGeometryAction(
    _ request: IPCRequest,
    action: String,
    operation: (Window, WindowGeometryChange) -> Bool
  ) throws -> IPCResponse {
    let selection = try parseValueSelection(request.args, action: action)

    guard let change = parseGeometryChange(selection.value) else {
      throw IPCCommandError.invalidRequest("invalid window \(action) value: \(selection.value)")
    }

    let window = try selectedWindow(selector: selection.selector)

    guard operation(window, change) else {
      throw IPCCommandError.internalError("could not \(action) window: \(window.id)")
    }

    return .success(id: request.id, message: "ok")
  }

  /// Move the selected window to another display.
  private func display(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseValueSelection(request.args, action: "display")
    guard let target = WindowDisplayTarget(argument: selection.value) else {
      throw IPCCommandError.invalidRequest("invalid window display value: \(selection.value)")
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
      throw IPCCommandError.invalidRequest("invalid window display value: \(selection.value)")
    }

    let targetFrame = WindowDisplayTransfer(
      windowFrame: frame,
      sourceFrame: sourceScreen.axVisibleFrame,
      targetFrame: targetScreen.axVisibleFrame
    ).targetWindowFrame()

    try applyFrame(
      targetFrame,
      currentFrame: frame,
      window: window,
      failureMessage: "could not move window to display: \(window.id)"
    )

    return .success(id: request.id, message: "ok")
  }

  /// Move and resize the selected window into a grid cell span.
  private func grid(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseValueSelection(request.args, action: "grid")

    guard let grid = WindowGrid(argument: selection.value) else {
      throw IPCCommandError.invalidRequest("invalid window grid value: \(selection.value)")
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

    try applyFrame(
      targetFrame,
      currentFrame: frame,
      window: window,
      failureMessage: "could not grid window: \(window.id)"
    )

    return .success(id: request.id, message: "ok")
  }

  /// Apply a multi-part frame change and report unrecoverable partial state.
  private func applyFrame(
    _ targetFrame: CGRect,
    currentFrame: CGRect,
    window: Window,
    failureMessage: String
  ) throws {
    switch window.setFrame(targetFrame, from: currentFrame) {
    case .success:
      return
    case .resizeFailed, .moveFailed:
      throw IPCCommandError.internalError(failureMessage)
    case .moveFailedAndRollbackFailed:
      throw IPCCommandError.internalError(
        "\(failureMessage); resize rollback failed and the window may be partially updated"
      )
    }
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
      guard let focusedWindowID = WindowManager.focusedWindowID() else {
        throw IPCCommandError.invalidRequest("no focused window")
      }
      windowID = focusedWindowID
    }

    guard let window = windowManager.window(by: windowID) else {
      throw IPCCommandError.invalidRequest("window not found: \(windowID)")
    }

    return window
  }

  /// Resolve the closest non-minimized window on the currently visible Spaces.
  private func directionalWindow(
    from sourceWindow: Window,
    in direction: CardinalDirection
  ) -> Window? {
    let windows = windowManager.allWindows()
    let topology = spaceManager.snapshotTopology(for: windows.map(\.id))
    let visibleSpaceIDs = Set(topology.visibleSpaceIDByDisplayID.values)
    let framesByWindowID = Dictionary(
      uniqueKeysWithValues: windows.compactMap { window -> (CGWindowID, CGRect)? in
        guard !window.isMinimized else { return nil }
        guard
          let spaceIDs = topology.spaceIDsByWindowID[window.id],
          !spaceIDs.isDisjoint(with: visibleSpaceIDs),
          let frame = window.frame()
        else {
          return nil
        }
        return (window.id, frame)
      }
    )

    guard let windowID = direction.neighbor(of: sourceWindow.id, in: framesByWindowID) else {
      return nil
    }
    return windowManager.window(by: windowID)
  }

  /// Parse an optional single window selector argument.
  private func parseSelector(_ args: [String], action: String) throws -> String? {
    guard args.count <= 1 else {
      throw IPCCommandError.invalidRequest("invalid window \(action) arguments")
    }

    return args.first
  }

  /// Parse an optional selector and one required action value.
  private func parseValueSelection(
    _ args: [String],
    action: String
  ) throws -> (selector: String?, value: String) {
    guard (1...2).contains(args.count) else {
      throw IPCCommandError.invalidRequest("invalid window \(action) arguments")
    }

    if args.count == 1 {
      return (selector: nil, value: args[0])
    }

    return (selector: args[0], value: args[1])
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

/// Parsed target for focusing a selected or directional window.
enum WindowFocusTarget: Equatable {
  case selected(String?)
  case direction(CardinalDirection)

  /// Parse an optional window selector or cardinal direction.
  init?(arguments: [String]) {
    guard arguments.count <= 1 else { return nil }

    if let argument = arguments.first,
      let direction = CardinalDirection(rawValue: argument)
    {
      self = .direction(direction)
    } else {
      self = .selected(arguments.first)
    }
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
