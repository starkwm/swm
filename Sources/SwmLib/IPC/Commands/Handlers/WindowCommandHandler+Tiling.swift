import CoreGraphics

extension WindowCommandHandler {
  func layout(_ request: IPCRequest) throws -> IPCResponse {
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

  func cycle(_ request: IPCRequest) throws -> IPCResponse {
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

  func swap(_ request: IPCRequest) throws -> IPCResponse {
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

  func swapCycle(_ request: IPCRequest) throws -> IPCResponse {
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

  func swapWithMaster(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "swap-with-master")
    let window = try selectedWindow(selector: selector)
    guard tiling.swapWindowWithMaster(window.id) else {
      throw IPCCommandError.invalidRequest("window is not in a master layout: \(window.id)")
    }
    return .acknowledged(id: request.id)
  }

  func focusMaster(_ request: IPCRequest) throws -> IPCResponse {
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

  func splitRatio(_ request: IPCRequest) throws -> IPCResponse {
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

  func toggleSplit(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "toggle-split")
    let window = try selectedWindow(selector: selector)
    guard tiling.toggleDwindleSplit(for: window.id) else {
      throw IPCCommandError.invalidRequest(
        "window has no dwindle split to toggle, or preserve-split is off: \(window.id)"
      )
    }
    return .acknowledged(id: request.id)
  }

  func swapSplit(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try parseSelector(request.args, action: "swap-split")
    let window = try selectedWindow(selector: selector)
    guard tiling.swapDwindleSplit(for: window.id) else {
      throw IPCCommandError.invalidRequest("window has no dwindle split to swap: \(window.id)")
    }
    return .acknowledged(id: request.id)
  }
}
