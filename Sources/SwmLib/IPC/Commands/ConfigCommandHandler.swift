/// Handles IPC commands that update global configuration for every known space.
@MainActor
struct ConfigCommandHandler {
  private let spaceManager: SpaceManager
  private let tilingManager: TilingManager

  /// Create a config command handler backed by space and tiling managers.
  init(spaceManager: SpaceManager, tilingManager: TilingManager) {
    self.spaceManager = spaceManager
    self.tilingManager = tilingManager
  }

  /// Dispatch a config IPC request to the matching setting update.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "window-gap":
        return try windowGap(request)
      case "top-padding":
        return try padding(request, side: .top)
      case "bottom-padding":
        return try padding(request, side: .bottom)
      case "left-padding":
        return try padding(request, side: .left)
      case "right-padding":
        return try padding(request, side: .right)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported config command: \(request.command)")
      }
    }
  }

  /// Set the window gap for every known space.
  private func windowGap(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid config window-gap arguments")
    }

    guard let gap = Int(request.args[0]) else {
      throw IPCCommandError.invalidRequest("invalid config window-gap value: \(request.args[0])")
    }

    spaceManager.updateAllSettings { settings in
      settings.gap = max(0, gap)
    }
    tilingManager.reflowVisibleSpaces()

    return .success(id: request.id, message: "ok")
  }

  /// Set one padding side for every known space.
  private func padding(_ request: IPCRequest, side: PaddingSide) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid config \(request.command) arguments")
    }

    guard let value = Int(request.args[0]) else {
      throw IPCCommandError.invalidRequest(
        "invalid config \(request.command) value: \(request.args[0])"
      )
    }

    spaceManager.updateAllSettings { settings in
      switch side {
      case .top:
        settings.padding.top = max(0, value)
      case .bottom:
        settings.padding.bottom = max(0, value)
      case .left:
        settings.padding.left = max(0, value)
      case .right:
        settings.padding.right = max(0, value)
      }
    }
    tilingManager.reflowVisibleSpaces()

    return .success(id: request.id, message: "ok")
  }
}

/// Single side of a space padding setting.
private enum PaddingSide {
  case top
  case bottom
  case left
  case right
}
