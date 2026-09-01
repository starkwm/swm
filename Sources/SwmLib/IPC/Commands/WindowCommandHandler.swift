import AppKit

/// Handles IPC commands that focus, minimize, move, resize, tile, and grid windows.
@MainActor
struct WindowCommandHandler {
  private let windows: Windows
  private let spaces: Spaces
  private let tiling: Tiling

  /// Create a window command handler backed by window, Space, and tiling services.
  init(
    windows: Windows,
    spaces: Spaces,
    tiling: Tiling
  ) {
    self.windows = windows
    self.spaces = spaces
    self.tiling = tiling
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
      case "--focus-master":
        return try focusMaster(request)
      case "--split-ratio":
        return try splitRatio(request)
      case "--toggle-split":
        return try toggleSplit(request)
      case "--swap-split":
        return try swapSplit(request)
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
    guard tiling.setWindowLayout(layout, for: window.id) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for window: \(window.id)")
    }
    return .success(id: request.id, message: layout.rawValue)
  }

  /// Focus the next available window in stable layout order.
  private func cycle(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "window cycle").requiredValue()
    guard let direction = CycleDirection(rawValue: argument) else {
      throw IPCCommandError.invalidRequest("invalid window cycle direction: \(argument)")
    }
    let window = try selectedWindow(selector: nil)
    guard let cycledWindowID = tiling.cycledWindowID(from: window.id, in: direction),
      let cycledWindow = windows.window(by: cycledWindowID)
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
    guard tiling.swapWindow(window.id, in: direction) else {
      throw IPCCommandError.invalidRequest(
        "window has no swappable neighbour in direction: \(direction.rawValue)"
      )
    }
    return .success(id: request.id, message: "ok")
  }

  /// Swap the focused tiled window with its neighbour in stable layout order.
  private func swapCycle(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "window swap-cycle").requiredValue()
    guard let direction = CycleDirection(rawValue: argument) else {
      throw IPCCommandError.invalidRequest(
        "invalid window swap-cycle direction: \(argument)"
      )
    }
    let window = try selectedWindow(selector: nil)
    guard tiling.swapWindowInOrder(window.id, in: direction) else {
      throw IPCCommandError.invalidRequest("window has no swap-cycle neighbour: \(window.id)")
    }
    return .success(id: request.id, message: "ok")
  }

  /// Swap the selected tiled window with the master pane.
  private func swapWithMaster(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "swap-with-master")
    let window = try selectedWindow(selector: selector)
    guard tiling.swapWindowWithMaster(window.id) else {
      throw IPCCommandError.invalidRequest("window is not in a master layout: \(window.id)")
    }
    return .success(id: request.id, message: "ok")
  }

  /// Focus the master window in the selected window's layout.
  private func focusMaster(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "focus-master")
    let window = try selectedWindow(selector: selector)
    guard let masterWindowID = tiling.masterWindowID(inLayoutContaining: window.id),
      let masterWindow = windows.window(by: masterWindowID)
    else {
      throw IPCCommandError.invalidRequest("window is not in a master layout: \(window.id)")
    }
    guard masterWindow.focus() else {
      throw IPCCommandError.internalError("could not focus window: \(masterWindow.id)")
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
    guard tiling.changeDwindleSplitRatio(change, for: window.id) != nil else {
      throw IPCCommandError.invalidRequest("window has no dwindle split: \(window.id)")
    }
    return .success(id: request.id, message: "ok")
  }

  /// Toggle and retain the selected window's nearest dwindle split direction.
  private func toggleSplit(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "toggle-split")
    let window = try selectedWindow(selector: selector)
    guard tiling.toggleDwindleSplit(for: window.id) else {
      throw IPCCommandError.invalidRequest(
        "window has no retained dwindle split to toggle: \(window.id)"
      )
    }
    return .success(id: request.id, message: "ok")
  }

  /// Exchange the selected window's nearest dwindle sibling subtrees.
  private func swapSplit(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "swap-split")
    let window = try selectedWindow(selector: selector)
    guard tiling.swapDwindleSplit(for: window.id) else {
      throw IPCCommandError.invalidRequest("window has no dwindle split to swap: \(window.id)")
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

    let settings = spaces.settings(for: spaceID)
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
    var result = window.setFrame(targetFrame, from: currentFrame)
    if result == .success,
      let appliedFrame = window.frame(),
      !appliedFrame.matches(targetFrame, tolerance: 1)
    {
      result = window.setFrame(targetFrame, from: appliedFrame)
    }

    switch result {
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
        guard let recentWindowID = windows.lastFocusedWindowID else {
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
      guard let focusedWindowID = Windows.focusedWindowID() else {
        throw IPCCommandError.invalidRequest("no focused window")
      }
      windowID = focusedWindowID
    }

    guard let window = windows.window(by: windowID) else {
      throw IPCCommandError.invalidRequest("window not found: \(windowID)")
    }

    return window
  }

  /// Resolve the closest non-minimized window on the currently visible Spaces.
  private func directionalWindow(
    from sourceWindow: Window,
    in direction: CardinalDirection
  ) -> Window? {
    let candidateWindows = windows.allWindows()
    let topology = spaces.snapshotTopology(for: candidateWindows.map(\.id))
    let visibleSpaceIDs = Set(topology.visibleSpaceIDByDisplayID.values)
    let framesByWindowID = Dictionary(
      uniqueKeysWithValues: candidateWindows.compactMap { window -> (CGWindowID, CGRect)? in
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
    return windows.window(by: windowID)
  }

  /// Parse an optional single window selector argument.
  private func parseSelector(_ args: [String], action: String) throws -> String? {
    try IPCArguments(args, context: "window \(action)").optionalValue()
  }

  /// Parse an optional selector and one required action value.
  private func parseValueSelection(
    _ args: [String],
    action: String
  ) throws -> (selector: String?, value: String) {
    try IPCArguments(args, context: "window \(action)").selectedValue()
  }

  /// Parse a geometry change in `mode:first:second` format.
  private func parseGeometryChange(_ argument: String) -> WindowGeometryChange? {
    let parts = argument.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

    guard
      parts.count == 3,
      let mode = NumericChangeMode(rawValue: parts[0]),
      let first = Int(parts[1]),
      let second = Int(parts[2])
    else {
      return nil
    }

    return WindowGeometryChange(mode: mode, first: first, second: second)
  }
}

/// Parsed two-axis window geometry change.
private struct WindowGeometryChange {
  let mode: NumericChangeMode
  let first: Int
  let second: Int
}
