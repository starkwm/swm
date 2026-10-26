/// Handles IPC commands that update global configuration for every known space.
@MainActor
struct ConfigCommandHandler {
  private let windows: Windows
  private let spaces: Spaces
  private let tiling: Tiling

  /// Create a config command handler backed by window, Space, and tiling services.
  init(windows: Windows, spaces: Spaces, tiling: Tiling) {
    self.windows = windows
    self.spaces = spaces
    self.tiling = tiling
  }

  /// Dispatch a config IPC request to the matching setting update.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "animation-easing":
        return try animationEasing(request)
      case "animation-duration":
        return try animationDuration(request)
      case "layout":
        return try layout(request)
      case "focus-follows-mouse":
        return try focusFollowsMouse(request)
      case "master-ratio":
        return try masterRatio(request)
      case "master-placement":
        return try masterPlacement(request)
      case "preserve-split":
        return try preserveSplitDirections(request)
      case "gap":
        return try gap(request)
      case "padding":
        return try padding(request)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported config command: \(request.command)")
      }
    }
  }

  private func animationEasing(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(
      request.args,
      context: "config animation-easing"
    ).requiredValue()
    guard let easing = AnimationEasing(rawValue: argument) else {
      throw IPCCommandError.invalidRequest(
        "animation-easing must be one of: \(AnimationEasing.allCases.map(\.rawValue).joined(separator: ", "))"
      )
    }
    tiling.setAnimationEasing(easing)
    return .success(id: request.id, message: easing.rawValue)
  }

  /// Configure window animations.
  private func animationDuration(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(
      request.args,
      context: "config animation-duration"
    ).requiredValue()
    guard let duration = Double(argument), duration.isFinite, (0...1).contains(duration) else {
      throw IPCCommandError.invalidRequest("animation-duration must be between 0 and 1 seconds")
    }
    tiling.setAnimationDuration(duration)
    return .success(id: request.id, message: "ok")
  }

  /// Select how pointer movement focuses managed windows.
  private func focusFollowsMouse(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(
      request.args,
      context: "config focus-follows-mouse"
    ).requiredValue()
    guard let mode = FocusFollowsMouseMode(rawValue: argument) else {
      throw IPCCommandError.invalidRequest(
        "invalid config focus-follows-mouse value: \(argument)"
      )
    }

    windows.setFocusFollowsMouseMode(mode)
    return .success(id: request.id, message: mode.rawValue)
  }

  /// Set the master pane ratio for every current and future Space.
  private func masterRatio(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "config master-ratio").requiredValue()
    guard let ratio = CommandValueParser.ratio(from: argument) else {
      throw IPCCommandError.invalidRequest("invalid config master-ratio value: \(argument)")
    }
    guard (0.1...0.9).contains(ratio) else {
      throw IPCCommandError.invalidRequest("master-ratio must be between 0.1 and 0.9")
    }
    tiling.setMasterRatioForAllSpaces(ratio)
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
    tiling.setMasterPlacementForAllSpaces(placement)
    return .success(id: request.id, message: placement.rawValue)
  }

  /// Set retained dwindle split directions for every current and future Space.
  private func preserveSplitDirections(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(
      request.args,
      context: "config preserve-split"
    ).requiredValue()
    guard let enabled = CommandValueParser.boolean(from: argument) else {
      throw IPCCommandError.invalidRequest("invalid config preserve-split value: \(argument)")
    }
    tiling.setSplitDirectionPreservationForAllSpaces(enabled)
    return .success(id: request.id, message: enabled ? "on" : "off")
  }

  /// Select floating or automatic layout for every Space.
  private func layout(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "config layout").requiredValue()
    guard let selection = LayoutSelection(rawValue: argument) else {
      throw IPCCommandError.invalidRequest("invalid config layout: \(argument)")
    }

    tiling.setLayoutForSpaces(selection)

    return .success(id: request.id, message: selection.rawValue)
  }

  /// Set the window gap for every known space.
  private func gap(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "config gap").requiredValue()
    guard let gap = Int(argument) else {
      throw IPCCommandError.invalidRequest("invalid config gap value: \(argument)")
    }

    spaces.updateAllSettings { settings in
      settings.gap = max(0, gap)
    }
    tiling.reflowVisibleSpaces()

    return .success(id: request.id, message: "ok")
  }

  /// Set padding sides for every known space.
  private func padding(_ request: IPCRequest) throws -> IPCResponse {
    guard !request.args.isEmpty else {
      throw IPCCommandError.invalidRequest("invalid config padding arguments")
    }
    let changes = try request.args.map { argument in
      guard let change = PaddingSideChange(argument: argument), change.mode == .absolute else {
        throw IPCCommandError.invalidValue(
          "config padding",
          argument,
          expected: "<side>=abs:<points>, such as top=abs:8"
        )
      }
      return change
    }

    try spaces.updateAllSettings { settings in
      settings.padding = try PaddingSideChange.applying(changes, to: settings.padding)
    }
    tiling.reflowVisibleSpaces()

    return .success(id: request.id, message: "ok")
  }
}
