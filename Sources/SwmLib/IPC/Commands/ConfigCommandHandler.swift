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
      case "layout":
        return try layout(request)
      case "master-ratio":
        return try masterRatio(request)
      case "master-placement":
        return try masterPlacement(request)
      case "preserve-split":
        return try preserveSplitDirections(request)
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

  /// Set the master pane ratio for every current and future Space.
  private func masterRatio(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "config master-ratio").requiredValue()
    guard let ratio = LayoutCommandParser.ratio(from: argument) else {
      throw IPCCommandError.invalidRequest("invalid config master-ratio value: \(argument)")
    }
    tilingManager.setMasterRatioForAllSpaces(ratio)
    return .success(id: request.id, message: "ok")
  }

  /// Set the master pane edge for every current and future Space.
  private func masterPlacement(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(
      request.args,
      context: "config master-placement"
    ).requiredValue()
    guard let placement = MasterPlacement(rawValue: argument) else {
      throw IPCCommandError.invalidRequest("invalid config master-placement: \(argument)")
    }
    tilingManager.setMasterPlacementForAllSpaces(placement)
    return .success(id: request.id, message: placement.rawValue)
  }

  /// Set retained dwindle split directions for every current and future Space.
  private func preserveSplitDirections(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(
      request.args,
      context: "config preserve-split"
    ).requiredValue()
    guard let enabled = LayoutCommandParser.boolean(from: argument) else {
      throw IPCCommandError.invalidRequest("invalid config preserve-split value: \(argument)")
    }
    tilingManager.setSplitDirectionPreservationForAllSpaces(enabled)
    return .success(id: request.id, message: enabled ? "on" : "off")
  }

  /// Select floating or automatic layout for every Space.
  private func layout(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "config layout").requiredValue()
    guard let selection = LayoutSelection(rawValue: argument) else {
      throw IPCCommandError.invalidRequest("invalid config layout: \(argument)")
    }

    tilingManager.setLayoutForSpaces(selection)

    return .success(id: request.id, message: selection.rawValue)
  }

  /// Set the window gap for every known space.
  private func windowGap(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "config window-gap").requiredValue()
    guard let gap = Int(argument) else {
      throw IPCCommandError.invalidRequest("invalid config window-gap value: \(argument)")
    }

    spaceManager.updateAllSettings { settings in
      settings.gap = max(0, gap)
    }
    tilingManager.reflowVisibleSpaces()

    return .success(id: request.id, message: "ok")
  }

  /// Set one padding side for every known space.
  private func padding(_ request: IPCRequest, side: PaddingSide) throws -> IPCResponse {
    let argument = try IPCArguments(
      request.args,
      context: "config \(request.command)"
    ).requiredValue()
    guard let value = Int(argument) else {
      throw IPCCommandError.invalidRequest(
        "invalid config \(request.command) value: \(argument)"
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
