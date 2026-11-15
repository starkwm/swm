import AppKit

@MainActor
struct WindowCommandHandler {
  private let windows: Windows
  private let spaces: Spaces
  private let tiling: Tiling

  init(
    windows: Windows,
    spaces: Spaces,
    tiling: Tiling
  ) {
    self.windows = windows
    self.spaces = spaces
    self.tiling = tiling
  }

  func dispatch(_ request: IPCRequest) async -> IPCResponse {
    await IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "--focus":
        return try focus(request)
      case "--warp":
        return try warp(request)
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
        return try performGeometryAction(
          request,
          action: "move",
          form: "abs|rel:<x>:<y>, such as rel:20:0"
        ) { $1.moving($0) }
      case "--resize":
        return try performGeometryAction(
          request,
          action: "resize",
          form: "abs|rel:<width>:<height>, such as rel:40:0",
          validate: { change, value in
            guard case .absolute(let size) = change, size.first <= 0 || size.second <= 0 else {
              return
            }
            throw IPCCommandError.invalidRequest("window size must be positive: \(value)")
          }
        ) { frame, change in
          let target = change.resizing(frame)
          guard target.width > 0, target.height > 0 else {
            throw IPCCommandError.invalidRequest(
              "window resize would leave a size of \(Int(target.width))x\(Int(target.height))"
            )
          }
          return target
        }
      case "--grid":
        return try grid(request)
      case "--display":
        return try display(request)
      case "--space":
        return try await space(request)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported window command: \(request.command)")
      }
    }
  }

  private func focus(_ request: IPCRequest) throws -> IPCResponse {
    guard let target = WindowTarget(arguments: request.args) else {
      throw IPCCommandError.invalidRequest("invalid window focus arguments")
    }

    let window: Window
    switch target {
    case .selected(let selector):
      window = try selectedWindow(selector: selector)
    case .direction(let direction):
      let sourceWindow = try selectedWindow(selector: nil)
      guard
        let directionalWindow = windows.directionalWindow(
          from: sourceWindow,
          in: direction,
          spaces: spaces
        )
      else {
        throw IPCCommandError.invalidRequest(
          "window has no focusable neighbour in direction: \(direction.rawValue)"
        )
      }
      window = directionalWindow
    }

    try window.focusOrThrow()

    return .acknowledged(id: request.id)
  }

  private func warp(_ request: IPCRequest) throws -> IPCResponse {
    guard let target = WindowTarget(arguments: request.args) else {
      throw IPCCommandError.invalidRequest("invalid window warp arguments")
    }

    let mouseWarp = WindowMouseWarp.shared
    let window: Window
    switch target {
    case .selected(let selector):
      window = try selectedWindow(selector: selector)
    case .direction(let direction):
      let sourceWindow = try mouseWarp.sourceWindow(
        windowByID: windows.window(by:),
        focusedWindow: { try selectedWindow(selector: nil) }
      )

      guard
        let neighbour = windows.directionalWindow(
          from: sourceWindow,
          in: direction,
          spaces: spaces,
          isEligible: mouseWarp.isOnScreen
        )
      else {
        throw IPCCommandError.invalidRequest(
          "window has no available neighbour in direction: \(direction.rawValue)"
        )
      }

      window = neighbour
    }

    try mouseWarp.warp(windowID: window.id, frame: window.frame())

    return .acknowledged(id: request.id)
  }

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

  private func cycle(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "window cycle").requiredValue()
    guard let direction = CycleDirection(rawValue: argument) else {
      throw IPCCommandError.invalidRequest("invalid window cycle direction: \(argument)")
    }
    tiling.reconcile()
    let focusedWindowID = Windows.focusedWindowID()
    guard
      let cycledWindowID = tiling.cycledWindowID(
        from: focusedWindowID,
        in: direction,
        fallbackSpaceID: spaces.resolveActiveSpaceID()
      ),
      let cycledWindow = windows.window(by: cycledWindowID)
    else {
      throw IPCCommandError.invalidRequest("no available window to cycle")
    }
    try cycledWindow.focusOrThrow()
    return .acknowledged(id: request.id)
  }

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
    return .acknowledged(id: request.id)
  }

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
    return .acknowledged(id: request.id)
  }

  private func swapWithMaster(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "swap-with-master")
    let window = try selectedWindow(selector: selector)
    guard tiling.swapWindowWithMaster(window.id) else {
      throw IPCCommandError.invalidRequest("window is not in a master layout: \(window.id)")
    }
    return .acknowledged(id: request.id)
  }

  private func focusMaster(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "focus-master")
    let window = try selectedWindow(selector: selector)
    guard let masterWindowID = tiling.masterWindowID(inLayoutContaining: window.id),
      let masterWindow = windows.window(by: masterWindowID)
    else {
      throw IPCCommandError.invalidRequest("window is not in a master layout: \(window.id)")
    }
    try masterWindow.focusOrThrow()
    return .acknowledged(id: request.id)
  }

  private func splitRatio(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseValueSelection(request.args, action: "split-ratio")
    guard let change = CommandValueParser.ratioChange(from: selection.value) else {
      throw IPCCommandError.invalidValue(
        "window split-ratio",
        selection.value,
        expected: CommandValueParser.ratioChangeForm
      )
    }
    let window = try selectedWindow(selector: selection.selector)
    guard tiling.changeDwindleSplitRatio(change, for: window.id) != nil else {
      throw IPCCommandError.invalidRequest("window has no dwindle split: \(window.id)")
    }
    return .acknowledged(id: request.id)
  }

  private func toggleSplit(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "toggle-split")
    let window = try selectedWindow(selector: selector)
    guard tiling.toggleDwindleSplit(for: window.id) else {
      throw IPCCommandError.invalidRequest(
        "window has no dwindle split to toggle, or preserve-split is off: \(window.id)"
      )
    }
    return .acknowledged(id: request.id)
  }

  private func swapSplit(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "swap-split")
    let window = try selectedWindow(selector: selector)
    guard tiling.swapDwindleSplit(for: window.id) else {
      throw IPCCommandError.invalidRequest("window has no dwindle split to swap: \(window.id)")
    }
    return .acknowledged(id: request.id)
  }

  private func performWindowAction(
    _ request: IPCRequest,
    action: String,
    operation: (Window) -> Bool
  ) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: action)
    let window = try selectedWindow(selector: selector)

    tiling.prepareForSynchronousMutation(for: window.id)
    guard operation(window) else {
      throw IPCCommandError.internalError("could not \(action) window: \(window.id)")
    }

    return .acknowledged(id: request.id)
  }

  private func performGeometryAction(
    _ request: IPCRequest,
    action: String,
    form: String,
    validate: (WindowGeometryChange, String) throws -> Void = { _, _ in },
    operation: (CGRect, WindowGeometryChange) throws -> CGRect
  ) throws -> IPCResponse {
    let selection = try parseValueSelection(request.args, action: action)

    guard let change = WindowGeometryChange(selection.value, value: WindowGeometryChange.pair)
    else {
      throw IPCCommandError.invalidValue("window \(action)", selection.value, expected: form)
    }
    try validate(change, selection.value)

    let window = try selectedWindow(selector: selection.selector)
    try requireUntiledWindow(window)

    guard let destination = tiling.destinationFrame(for: window.id) ?? window.frame() else {
      throw IPCCommandError.internalError("could not \(action) window: \(window.id)")
    }
    try applyFrame(
      try operation(destination, change),
      window: window,
      failureMessage: "could not \(action) window: \(window.id)"
    )

    return .acknowledged(id: request.id)
  }

  private func display(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseValueSelection(request.args, action: "move --display")
    let invalidDisplay = IPCCommandError.invalidValue(
      "window move --display",
      selection.value,
      expected: "a one-based display index, next, or prev"
    )
    guard let target = WindowDisplayTarget(argument: selection.value) else {
      throw invalidDisplay
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
      throw invalidDisplay
    }

    try transfer(
      window,
      frame: frame,
      from: sourceScreen,
      to: targetScreen,
      failureMessage: "could not move window to display: \(window.id)"
    )

    return .acknowledged(id: request.id)
  }

  private func space(_ request: IPCRequest) async throws -> IPCResponse {
    let selection = try parseValueSelection(request.args, action: "move --space")

    guard let target = WindowSpaceTarget(argument: selection.value) else {
      throw IPCCommandError.invalidValue(
        "window move --space",
        selection.value,
        expected: "a one-based Space index, next, or prev"
      )
    }

    let window = try selectedWindow(selector: selection.selector)
    let windowID = window.id

    try requireUndraggedWindow(windowID)

    tiling.prepareForSynchronousMutation(for: windowID)
    defer {
      if !Task.isCancelled { tiling.reconcileAndReflowVisibleSpaces() }
    }

    try await WindowSpaceTransfer.shared.move(window, to: target) {
      window.id == windowID && windows.window(by: windowID) === window
    } fit: { _, targetFrame, destinationID in
      try applyFrame(
        targetFrame,
        window: window,
        failureMessage:
          "window moved to Space \(destinationID), but display placement failed: \(windowID)",
        animated: false
      )

      guard Set(WindowServerClient.shared.spaceIDs(containing: windowID)) == [destinationID] else {
        throw IPCCommandError.internalError(
          "display placement changed window \(windowID)'s membership in Space \(destinationID)"
        )
      }
    }

    return .acknowledged(id: request.id)
  }

  private func grid(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try parseValueSelection(request.args, action: "grid")

    guard let grid = WindowGrid(argument: selection.value) else {
      throw IPCCommandError.invalidValue(
        "window grid",
        selection.value,
        expected: "columns:rows:x:y:width:height, such as 2:1:0:0:1:1"
      )
    }

    let window = try selectedWindow(selector: selection.selector)
    try requireUntiledWindow(window)

    guard
      let frame = window.frame(),
      let screen = NSScreen.screen(containingLargestIntersectionWith: frame),
      let spaceID = WindowServerClient.shared.spaceIDs(containing: window.id).first
    else {
      throw IPCCommandError.internalError("could not grid window: \(window.id)")
    }

    let settings = spaces.settings(for: spaceID)
    let bounds = screen.axVisibleFrame
    guard let targetFrame = grid.frame(in: bounds, settings: settings) else {
      throw IPCCommandError.invalidRequest("window grid has no usable bounds")
    }

    try applyFrame(
      targetFrame,
      window: window,
      failureMessage: "could not grid window: \(window.id)"
    )

    return .acknowledged(id: request.id)
  }

  private func transfer(
    _ window: Window,
    frame: CGRect,
    from sourceScreen: NSScreen,
    to targetScreen: NSScreen,
    failureMessage: String
  ) throws {
    let targetFrame = WindowDisplayTransfer(
      windowFrame: frame,
      sourceFrame: sourceScreen.axVisibleFrame,
      targetFrame: targetScreen.axVisibleFrame
    ).targetWindowFrame()
    try applyFrame(targetFrame, window: window, failureMessage: failureMessage, animated: false)
  }

  private func requireUntiledWindow(_ window: Window) throws {
    guard !tiling.isWindowTiled(window.id) else {
      throw IPCCommandError.invalidRequest("window is tiled: \(window.id)")
    }
  }

  private func requireUndraggedWindow(_ windowID: CGWindowID) throws {
    guard !tiling.isInteractingWithWindow(windowID) else {
      throw IPCCommandError.invalidRequest("window is being dragged: \(windowID)")
    }
  }

  private func applyFrame(
    _ targetFrame: CGRect,
    window: Window,
    failureMessage: String,
    animated: Bool = true
  ) throws {
    try requireUndraggedWindow(window.id)
    if animated, tiling.animateFrame(targetFrame, for: window.id) { return }
    tiling.prepareForSynchronousMutation(for: window.id)
    guard let currentFrame = window.frame() else {
      throw IPCCommandError.internalError(failureMessage)
    }
    switch window.setFrame(targetFrame, from: currentFrame) {
    case .success:
      return
    case .resizeFailed, .moveFailed:
      throw IPCCommandError.internalError(failureMessage)
    case .resizeFailedAndRollbackFailed:
      throw IPCCommandError.internalError(
        "\(failureMessage); position rollback failed and the window may be partially updated"
      )
    case .moveFailedAndRollbackFailed:
      throw IPCCommandError.internalError(
        "\(failureMessage); resize rollback failed and the window may be partially updated"
      )
    }
  }

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

  private func parseSelector(_ args: [String], action: String) throws -> String? {
    try IPCArguments(args, context: "window \(action)").optionalValue()
  }

  private func parseValueSelection(
    _ args: [String],
    action: String
  ) throws -> (selector: String?, value: String) {
    try IPCArguments(args, context: "window \(action)").selectedValue()
  }
}

private typealias WindowGeometryChange = NumericChange<(first: Int, second: Int)>

extension WindowGeometryChange {
  fileprivate static func pair(_ text: String) -> (first: Int, second: Int)? {
    let parts = text.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2, let first = Int(parts[0]), let second = Int(parts[1]) else {
      return nil
    }
    return (first, second)
  }

  fileprivate func moving(_ frame: CGRect) -> CGRect {
    var target = frame
    switch self {
    case .absolute(let point):
      target.origin = CGPoint(x: point.first, y: point.second)
    case .relative(let delta):
      target.origin.x += CGFloat(delta.first)
      target.origin.y += CGFloat(delta.second)
    }
    return target
  }

  fileprivate func resizing(_ frame: CGRect) -> CGRect {
    var target = frame
    switch self {
    case .absolute(let size):
      target.size = CGSize(width: size.first, height: size.second)
    case .relative(let delta):
      target.size.width += CGFloat(delta.first)
      target.size.height += CGFloat(delta.second)
    }
    return target
  }
}
