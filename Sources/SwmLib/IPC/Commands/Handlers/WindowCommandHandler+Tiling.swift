import CoreGraphics

extension WindowCommandHandler {
  func layout(
    id: String,
    selection: WindowSelection,
    layout: WindowLayoutSelection
  ) throws -> IPCResponse {
    let window = try selectedWindow(selection)
    guard tiling.setWindowLayout(layout, for: window.id) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for window: \(window.id)")
    }
    return .success(id: id, message: layout.rawValue)
  }

  func cycle(id: String, direction: CycleDirection) throws -> IPCResponse {
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
    return .acknowledged(id: id)
  }

  func swap(
    id: String,
    selection: WindowSelection,
    direction: CardinalDirection
  ) throws -> IPCResponse {
    let window = try selectedWindow(selection)
    guard tiling.swapWindow(window.id, in: direction) else {
      throw IPCCommandError.invalidRequest(
        "window has no swappable neighbour in direction: \(direction.rawValue)"
      )
    }
    return .acknowledged(id: id)
  }

  func swapCycle(id: String, direction: CycleDirection) throws -> IPCResponse {
    let window = try selectedWindow(.focused)
    guard tiling.swapWindowInOrder(window.id, in: direction) else {
      throw IPCCommandError.invalidRequest("window has no swap-cycle neighbour: \(window.id)")
    }
    return .acknowledged(id: id)
  }

  func swapWithMaster(id: String, selection: WindowSelection) throws -> IPCResponse {
    let window = try selectedWindow(selection)
    guard tiling.swapWindowWithMaster(window.id) else {
      throw IPCCommandError.invalidRequest("window is not in a master layout: \(window.id)")
    }
    return .acknowledged(id: id)
  }

  func focusMaster(id: String, selection: WindowSelection) throws -> IPCResponse {
    let window = try selectedWindow(selection)
    guard let masterWindowID = tiling.masterWindowID(inLayoutContaining: window.id),
      let masterWindow = windows.window(by: masterWindowID)
    else {
      throw IPCCommandError.invalidRequest("window is not in a master layout: \(window.id)")
    }
    try masterWindow.focusOrThrow()
    return .acknowledged(id: id)
  }

  func splitRatio(
    id: String,
    selection: WindowSelection,
    change: LayoutRatioChange
  ) throws -> IPCResponse {
    let window = try selectedWindow(selection)
    guard tiling.changeDwindleSplitRatio(change, for: window.id) != nil else {
      throw IPCCommandError.invalidRequest("window has no dwindle split: \(window.id)")
    }
    return .acknowledged(id: id)
  }

  func toggleSplit(id: String, selection: WindowSelection) throws -> IPCResponse {
    let window = try selectedWindow(selection)
    guard tiling.toggleDwindleSplit(for: window.id) else {
      throw IPCCommandError.invalidRequest(
        "window has no dwindle split to toggle, or preserve-split is off: \(window.id)"
      )
    }
    return .acknowledged(id: id)
  }

  func swapSplit(id: String, selection: WindowSelection) throws -> IPCResponse {
    let window = try selectedWindow(selection)
    guard tiling.swapDwindleSplit(for: window.id) else {
      throw IPCCommandError.invalidRequest("window has no dwindle split to swap: \(window.id)")
    }
    return .acknowledged(id: id)
  }
}
