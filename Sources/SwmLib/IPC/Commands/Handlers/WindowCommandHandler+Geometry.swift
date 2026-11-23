import AppKit

extension WindowCommandHandler {
  func move(
    id: String,
    selection: WindowSelection,
    change: NumericChange<IntPair>
  ) throws -> IPCResponse {
    try performGeometryAction(id: id, selection: selection, change: change, action: "move") {
      $1.moving($0)
    }
  }

  func resize(
    id: String,
    selection: WindowSelection,
    change: NumericChange<IntPair>
  ) throws -> IPCResponse {
    try performGeometryAction(
      id: id,
      selection: selection,
      change: change,
      action: "resize",
      validate: { change in
        guard case .absolute(let size) = change, size.first <= 0 || size.second <= 0 else {
          return
        }
        throw IPCCommandError.invalidRequest(
          "window size must be positive: \(size.first)x\(size.second)"
        )
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

  func display(
    id: String,
    selection: WindowSelection,
    target: WindowDisplayTarget
  ) throws -> IPCResponse {
    let window = try selectedWindow(selection)

    guard let frame = window.frame() else {
      throw IPCCommandError.internalError("could not move window to display: \(window.id)")
    }

    guard let sourceScreen = NSScreen.screen(containingLargestIntersectionWith: frame) else {
      throw IPCCommandError.internalError("could not move window to display: \(window.id)")
    }

    guard let targetScreen = target.screen(from: sourceScreen, screens: NSScreen.arrangedScreens)
    else {
      throw IPCCommandError.invalidRequest("could not locate target display")
    }

    try transfer(
      window,
      frame: frame,
      from: sourceScreen,
      to: targetScreen,
      failureMessage: "could not move window to display: \(window.id)"
    )

    return .acknowledged(id: id)
  }

  func space(
    id: String,
    selection: WindowSelection,
    target: WindowSpaceTarget
  ) async throws -> IPCResponse {
    let window = try selectedWindow(selection)
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

    return .acknowledged(id: id)
  }

  func grid(
    id: String,
    selection: WindowSelection,
    grid: WindowGrid
  ) throws -> IPCResponse {
    let window = try selectedWindow(selection)
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

    return .acknowledged(id: id)
  }

  private func performGeometryAction(
    id: String,
    selection: WindowSelection,
    change: NumericChange<IntPair>,
    action: String,
    validate: (NumericChange<IntPair>) throws -> Void = { _ in },
    operation: (CGRect, NumericChange<IntPair>) throws -> CGRect
  ) throws -> IPCResponse {
    try validate(change)

    let window = try selectedWindow(selection)
    try requireUntiledWindow(window)

    guard let destination = tiling.destinationFrame(for: window.id) ?? window.frame() else {
      throw IPCCommandError.internalError("could not \(action) window: \(window.id)")
    }
    try applyFrame(
      try operation(destination, change),
      window: window,
      failureMessage: "could not \(action) window: \(window.id)"
    )

    return .acknowledged(id: id)
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

extension NumericChange<IntPair> {
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
