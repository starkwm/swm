@MainActor
struct ConfigCommandHandler {
  private let windows: Windows
  private let spaces: Spaces
  private let tiling: Tiling
  private let arguments = SettingArguments(scope: "config")

  init(windows: Windows, spaces: Spaces, tiling: Tiling) {
    self.windows = windows
    self.spaces = spaces
    self.tiling = tiling
  }

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
      case "split-ratio":
        return try splitRatio(request)
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

  private func currentValue(of setting: String) -> String? {
    switch setting {
    case "animation-easing": tiling.animationEasing.rawValue
    case "animation-duration": String(tiling.animationDuration)
    case "focus-follows-mouse": windows.focusFollowsMouseMode.rawValue
    default:
      SettingArguments.currentValue(of: setting, in: spaces.defaultSettings)
        ?? SettingArguments.currentValue(of: setting, in: tiling.defaultState)
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

  private func masterRatio(_ request: IPCRequest) throws -> IPCResponse {
    tiling.changeMasterRatioForAllSpaces(
      try arguments.ratioChange(request.args, setting: "master-ratio")
    )
    return .acknowledged(id: request.id)
  }

  private func masterPlacement(_ request: IPCRequest) throws -> IPCResponse {
    let placement =
      switch try arguments.masterPlacement(request.args) {
      case .set(let placement): placement
      case .cycle(let direction): tiling.defaultState.masterPlacement.cycled(in: direction)
      }
    tiling.setMasterPlacementForAllSpaces(placement)
    return .success(id: request.id, message: placement.rawValue)
  }

  private func splitRatio(_ request: IPCRequest) throws -> IPCResponse {
    tiling.changeSplitRatioForAllSpaces(
      try arguments.ratioChange(request.args, setting: "split-ratio")
    )
    return .acknowledged(id: request.id)
  }

  private func preserveSplitDirections(_ request: IPCRequest) throws -> IPCResponse {
    let enabled = try arguments.preserveSplit(request.args)
    tiling.setSplitDirectionPreservationForAllSpaces(enabled)
    return .success(id: request.id, message: enabled ? "on" : "off")
  }

  private func layout(_ request: IPCRequest) throws -> IPCResponse {
    let selection = try arguments.layout(request.args)
    tiling.setLayoutForSpaces(selection)

    return .success(id: request.id, message: selection.rawValue)
  }

  private func gap(_ request: IPCRequest) throws -> IPCResponse {
    let gap = try arguments.gap(request.args, current: spaces.defaultSettings.gap)
    spaces.updateAllSettings { settings in
      settings.gap = max(0, gap)
    }
    tiling.reflowVisibleSpaces()

    return .acknowledged(id: request.id)
  }

  private func padding(_ request: IPCRequest) throws -> IPCResponse {
    let changes = try arguments.paddingChanges(request.args)
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
