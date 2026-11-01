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
      if request.args.isEmpty, let value = currentValue(of: request.command) {
        return .success(id: request.id, message: value)
      }

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

  /// The current global value of a setting, in the form its command accepts.
  private func currentValue(of setting: String) -> String? {
    let state = tiling.defaultState
    let settings = spaces.defaultSettings
    switch setting {
    case "animation-easing": return tiling.animationEasing.rawValue
    case "animation-duration": return String(tiling.animationDuration)
    case "layout": return state.selection.rawValue
    case "focus-follows-mouse": return windows.focusFollowsMouseMode.rawValue
    case "master-ratio": return String(Double(state.masterRatio))
    case "master-placement": return state.masterPlacement.rawValue
    case "preserve-split": return state.preserveSplitDirections ? "on" : "off"
    case "gap": return String(settings.gap)
    case "padding": return settings.padding.commandOptions
    default: return nil
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
    return .acknowledged(id: request.id)
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

  /// Set or adjust the global master pane ratio, and apply it to every current and future Space.
  private func masterRatio(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "config master-ratio").requiredValue()
    guard let change = CommandValueParser.ratioChange(from: argument) else {
      throw IPCCommandError.invalidValue(
        "config master-ratio",
        argument,
        expected: CommandValueParser.ratioChangeForm
      )
    }
    if case .absolute(let ratio) = change, !(0.1...0.9).contains(ratio) {
      throw IPCCommandError.invalidRequest("master-ratio must be between 0.1 and 0.9")
    }
    tiling.changeMasterRatioForAllSpaces(change)
    return .acknowledged(id: request.id)
  }

  /// Set or cycle the global master pane edge, and apply it to every current and future Space.
  private func masterPlacement(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(
      request.args,
      context: "config master-placement"
    ).requiredValue()
    let placement: MasterPlacement
    if let selectedPlacement = MasterPlacement(rawValue: argument) {
      placement = selectedPlacement
    } else if let direction = CycleDirection(rawValue: argument) {
      placement = tiling.defaultState.masterPlacement.cycled(in: direction)
    } else {
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

  /// Set or adjust the global window gap, and apply it to every known space.
  private func gap(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "config gap").requiredValue()
    guard let change = CommandValueParser.pointsChange(from: argument) else {
      throw IPCCommandError.invalidValue(
        "config gap",
        argument,
        expected: CommandValueParser.pointsChangeForm
      )
    }

    var gap = change.value
    if change.mode == .relative {
      let (sum, overflow) = spaces.defaultSettings.gap.addingReportingOverflow(change.value)
      guard !overflow else {
        throw IPCCommandError.invalidRequest("config gap adjustment overflows integer range")
      }
      gap = sum
    }

    spaces.updateAllSettings { settings in
      settings.gap = max(0, gap)
    }
    tiling.reflowVisibleSpaces()

    return .acknowledged(id: request.id)
  }

  /// Set or adjust global padding sides, and apply the changed sides to every known space.
  private func padding(_ request: IPCRequest) throws -> IPCResponse {
    let changes = try request.args.map { argument in
      guard let change = PaddingSideChange(argument: argument) else {
        throw IPCCommandError.invalidValue(
          "config padding",
          argument,
          expected: PaddingSideChange.form
        )
      }
      return change
    }

    let padding = try PaddingSideChange.applying(
      changes,
      to: spaces.defaultSettings.padding,
      context: "config padding"
    )
    spaces.updateAllSettings { settings in
      for change in changes {
        settings.padding[change.side] = padding[change.side]
      }
    }
    tiling.reflowVisibleSpaces()

    return .acknowledged(id: request.id)
  }
}
