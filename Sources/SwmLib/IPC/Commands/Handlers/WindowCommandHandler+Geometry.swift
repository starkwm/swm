import AppKit

extension WindowCommandHandler {
  func move(_ request: IPCRequest) throws -> IPCResponse {
    try performGeometryAction(
      request,
      action: "move",
      form: "abs|rel:<x>:<y>, such as rel:20:0"
    ) { $1.moving($0) }
  }

  func resize(_ request: IPCRequest) throws -> IPCResponse {
    try performGeometryAction(
      request,
      action: "resize",
      form: "abs|rel:<width>:<height>, such as rel:40:0",
      validate: { change, value in
        guard case .absolute(let size) = change, size.first <= 0 || size.second <= 0 else {
          return
        }
        throw IPCCommandError.invalidRequest("window size must be positive: \(value)")
      },
      operation: { frame, change in
        let target = change.resizing(frame)
        guard target.width > 0, target.height > 0 else {
          throw IPCCommandError.invalidRequest(
            "window resize would leave a size of \(Int(target.width))x\(Int(target.height))"
          )
        }
        return target
      }
    )
  }

  func display(_ request: IPCRequest) throws -> IPCResponse {
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

  func space(_ request: IPCRequest) async throws -> IPCResponse {
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

  func grid(_ request: IPCRequest) throws -> IPCResponse {
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
