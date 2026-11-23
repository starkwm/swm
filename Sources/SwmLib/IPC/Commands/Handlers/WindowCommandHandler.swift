import AppKit

@MainActor
struct WindowCommandHandler {
  let windows: Windows
  let spaces: Spaces
  let tiling: Tiling

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
        return try move(request)
      case "--resize":
        return try resize(request)
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

  func selectedWindow(selector: String?) throws -> Window {
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

  func parseSelector(_ args: [String], action: String) throws -> String? {
    try IPCArguments(args, context: "window \(action)").optionalValue()
  }

  func parseValueSelection(
    _ args: [String],
    action: String
  ) throws -> (selector: String?, value: String) {
    try IPCArguments(args, context: "window \(action)").selectedValue()
  }
}
