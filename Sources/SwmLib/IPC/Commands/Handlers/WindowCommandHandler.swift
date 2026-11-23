import AppKit

@MainActor
struct WindowCommandHandler {
  let windows: Windows
  let spaces: Spaces
  let tiling: Tiling

  func dispatch(id: String, command: IPCCommand.Window) async -> IPCResponse {
    await IPCCommandError.catching(id: id) {
      switch command {
      case .focus(let target):
        return try focus(id: id, target: target)
      case .warp(let target):
        return try warp(id: id, target: target)
      case .minimize(let selection):
        return try performWindowAction(id: id, selection: selection, action: "minimize") {
          $0.minimize()
        }
      case .unminimize(let selection):
        return try performWindowAction(id: id, selection: selection, action: "unminimize") {
          $0.unminimize()
        }
      case .layout(let selection, let layout):
        return try self.layout(id: id, selection: selection, layout: layout)
      case .focusCycle(let direction):
        return try cycle(id: id, direction: direction)
      case .swap(let selection, let direction):
        return try swap(id: id, selection: selection, direction: direction)
      case .swapCycle(let direction):
        return try swapCycle(id: id, direction: direction)
      case .swapWithMaster(let selection):
        return try swapWithMaster(id: id, selection: selection)
      case .focusMaster(let selection):
        return try focusMaster(id: id, selection: selection)
      case .splitRatio(let selection, let change):
        return try splitRatio(id: id, selection: selection, change: change)
      case .toggleSplit(let selection):
        return try toggleSplit(id: id, selection: selection)
      case .swapSplit(let selection):
        return try swapSplit(id: id, selection: selection)
      case .move(let selection, let change):
        return try move(id: id, selection: selection, change: change)
      case .resize(let selection, let change):
        return try resize(id: id, selection: selection, change: change)
      case .grid(let selection, let grid):
        return try self.grid(id: id, selection: selection, grid: grid)
      case .display(let selection, let target):
        return try display(id: id, selection: selection, target: target)
      case .space(let selection, let target):
        return try await space(id: id, selection: selection, target: target)
      }
    }
  }

  private func focus(id: String, target: WindowTarget) throws -> IPCResponse {
    let window: Window
    switch target {
    case .selected(let selection):
      window = try selectedWindow(selection)
    case .direction(let direction):
      let sourceWindow = try selectedWindow(.focused)
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

    return .acknowledged(id: id)
  }

  private func warp(id: String, target: WindowTarget) throws -> IPCResponse {
    let mouseWarp = WindowMouseWarp.shared
    let window: Window
    switch target {
    case .selected(let selection):
      window = try selectedWindow(selection)
    case .direction(let direction):
      let sourceWindow = try mouseWarp.sourceWindow(
        windowByID: windows.window(by:),
        focusedWindow: { try selectedWindow(.focused) }
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

    return .acknowledged(id: id)
  }

  private func performWindowAction(
    id: String,
    selection: WindowSelection,
    action: String,
    operation: (Window) -> Bool
  ) throws -> IPCResponse {
    let window = try selectedWindow(selection)

    tiling.prepareForSynchronousMutation(for: window.id)
    guard operation(window) else {
      throw IPCCommandError.internalError("could not \(action) window: \(window.id)")
    }

    return .acknowledged(id: id)
  }

  func selectedWindow(_ selection: WindowSelection) throws -> Window {
    let windowID: CGWindowID

    switch selection {
    case .focused:
      guard let focusedWindowID = Windows.focusedWindowID() else {
        throw IPCCommandError.invalidRequest("no focused window")
      }
      windowID = focusedWindowID

    case .recent:
      guard let recentWindowID = windows.lastFocusedWindowID else {
        throw IPCCommandError.invalidRequest("no recent window")
      }
      windowID = recentWindowID

    case .id(let id):
      guard id != 0 else {
        throw IPCCommandError.invalidRequest("invalid window selector: 0")
      }
      windowID = id
    }

    guard let window = windows.window(by: windowID) else {
      throw IPCCommandError.invalidRequest("window not found: \(windowID)")
    }

    return window
  }
}
