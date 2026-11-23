struct SettingArguments {
  static func currentValue(of setting: String, in settings: SpaceSettings) -> String? {
    switch setting {
    case "gap": String(settings.gap)
    case "padding": settings.padding.commandOptions
    default: nil
    }
  }

  static func currentValue(of setting: String, in state: TilingLayoutState) -> String? {
    switch setting {
    case "layout": state.selection.rawValue
    case "master-ratio": String(Double(state.masterRatio))
    case "master-placement": state.masterPlacement.rawValue
    case "split-ratio": String(Double(state.splitRatio))
    case "preserve-split": state.preserveSplitDirections ? "on" : "off"
    default: nil
    }
  }

  let scope: String

  func layout(_ args: [String]) throws -> LayoutSelection {
    let argument = try IPCArguments(args, context: "\(scope) layout").requiredValue()
    guard let selection = LayoutSelection(rawValue: argument) else {
      throw IPCCommandError.invalidRequest("invalid \(scope) layout: \(argument)")
    }
    return selection
  }

  func ratioChange(_ args: [String], setting: String) throws -> LayoutRatioChange {
    let context = "\(scope) \(setting)"
    let argument = try IPCArguments(args, context: context).requiredValue()
    guard let change = CommandValueParser.ratioChange(from: argument) else {
      throw IPCCommandError.invalidValue(
        context,
        argument,
        expected: CommandValueParser.ratioChangeForm
      )
    }
    if case .absolute(let ratio) = change, !TilingLimits.ratioRange.contains(ratio) {
      throw IPCCommandError.invalidRequest("\(setting) must be between 0.1 and 0.9")
    }
    return change
  }

  func masterPlacement(_ args: [String]) throws -> MasterPlacementChange {
    let argument = try IPCArguments(args, context: "\(scope) master-placement").requiredValue()
    if let placement = MasterPlacement(rawValue: argument) {
      return .set(placement)
    }
    if let direction = CycleDirection(rawValue: argument) {
      return .cycle(direction)
    }
    throw IPCCommandError.invalidRequest("invalid \(scope) master-placement: \(argument)")
  }

  func preserveSplit(_ args: [String]) throws -> Bool {
    let argument = try IPCArguments(args, context: "\(scope) preserve-split").requiredValue()
    guard let enabled = CommandValueParser.boolean(from: argument) else {
      throw IPCCommandError.invalidRequest("invalid \(scope) preserve-split value: \(argument)")
    }
    return enabled
  }

  func gap(_ args: [String], current: Int) throws -> Int {
    let context = "\(scope) gap"
    let argument = try IPCArguments(args, context: context).requiredValue()
    guard let change = NumericChange(argument, value: { Int($0) }) else {
      throw IPCCommandError.invalidValue(
        context,
        argument,
        expected: CommandValueParser.pointsChangeForm
      )
    }
    return try change.applying(to: current, context: context)
  }

  func paddingChanges(_ args: [String]) throws -> [PaddingSideChange] {
    try args.map { argument in
      guard let change = PaddingSideChange(argument: argument) else {
        throw IPCCommandError.invalidValue(
          "\(scope) padding",
          argument,
          expected: PaddingSideChange.form
        )
      }
      return change
    }
  }
}

enum MasterPlacementChange: Equatable {
  case set(MasterPlacement)

  case cycle(CycleDirection)
}
