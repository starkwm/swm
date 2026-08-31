/// Handles IPC commands that update the selected space.
@MainActor
struct SpaceCommandHandler {
  private let spaces: Spaces
  private let tiling: Tiling
  private let spaceIDProvider: () -> [UInt64]

  /// Create a space command handler backed by space and tiling services.
  init(
    spaces: Spaces,
    tiling: Tiling,
    spaceIDProvider: @escaping () -> [UInt64] = { Spaces.all().map(\.id) }
  ) {
    self.spaces = spaces
    self.tiling = tiling
    self.spaceIDProvider = spaceIDProvider
  }

  /// Dispatch a space IPC request to the matching selected-space update.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      let operation: (IPCRequest, UInt64) throws -> IPCResponse

      switch request.command {
      case "--layout":
        operation = layout
      case "--master-ratio":
        operation = masterRatio
      case "--master-placement":
        operation = masterPlacement
      case "--preserve-split":
        operation = preserveSplitDirections
      case "--padding":
        operation = padding
      case "--gap":
        operation = gap
      default:
        throw IPCCommandError.unsupportedCommand("unsupported space command: \(request.command)")
      }

      let (targetedRequest, spaceID) = try targetedRequest(request)
      return try operation(targetedRequest, spaceID)
    }
  }

  /// Set or adjust the master pane ratio for the selected Space.
  private func masterRatio(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "space master-ratio").requiredValue()
    guard let change = CommandValueParser.ratioChange(from: argument) else {
      throw IPCCommandError.invalidRequest("invalid space master-ratio value: \(argument)")
    }

    guard tiling.changeMasterRatio(change, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return .success(id: request.id, message: "ok")
  }

  /// Set or cycle the master pane edge for the selected Space.
  private func masterPlacement(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse {
    let argument = try IPCArguments(
      request.args,
      context: "space master-placement"
    ).requiredValue()
    let placement: MasterPlacement
    if let selectedPlacement = MasterPlacement(rawValue: argument) {
      guard tiling.setMasterPlacement(selectedPlacement, for: spaceID) else {
        throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
      }
      placement = selectedPlacement
    } else if let direction = CycleDirection(rawValue: argument) {
      guard let cycledPlacement = tiling.cycleMasterPlacement(direction, for: spaceID) else {
        throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
      }
      placement = cycledPlacement
    } else {
      throw IPCCommandError.invalidRequest("invalid space master-placement: \(argument)")
    }
    return .success(id: request.id, message: placement.rawValue)
  }

  /// Set whether dwindle branches preserve their resolved direction on the selected Space.
  private func preserveSplitDirections(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse
  {
    let argument = try IPCArguments(
      request.args,
      context: "space preserve-split"
    ).requiredValue()
    guard let enabled = CommandValueParser.boolean(from: argument) else {
      throw IPCCommandError.invalidRequest("invalid space preserve-split value: \(argument)")
    }

    guard tiling.setSplitDirectionPreservation(enabled, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return .success(id: request.id, message: enabled ? "on" : "off")
  }

  /// Select floating or automatic layout for the selected Space.
  private func layout(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "space layout").requiredValue()
    guard let selection = LayoutSelection(rawValue: argument) else {
      throw IPCCommandError.invalidRequest("invalid space layout: \(argument)")
    }

    guard tiling.setLayout(selection, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }

    return .success(id: request.id, message: selection.rawValue)
  }

  /// Set or adjust padding for the selected space.
  private func padding(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "space padding").requiredValue()
    guard let change = parsePaddingChange(argument) else {
      throw IPCCommandError.invalidRequest("invalid space padding value: \(argument)")
    }

    switch change.mode {
    case .absolute:
      spaces.setPadding(change.padding, for: spaceID)
    case .relative:
      spaces.adjustPadding(change.padding, for: spaceID)
    }

    tiling.reflow(spaceID: spaceID)

    return .success(id: request.id, message: "ok")
  }

  /// Set or adjust the window gap for the selected space.
  private func gap(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "space gap").requiredValue()
    guard let change = parseGapChange(argument) else {
      throw IPCCommandError.invalidRequest("invalid space gap value: \(argument)")
    }

    switch change.mode {
    case .absolute:
      spaces.setGap(change.value, for: spaceID)
    case .relative:
      spaces.adjustGap(change.value, for: spaceID)
    }

    tiling.reflow(spaceID: spaceID)

    return .success(id: request.id, message: "ok")
  }

  /// Return the currently active space ID.
  private func currentSpaceID() throws -> UInt64 {
    guard let id = spaces.currentActiveSpaceID else {
      throw IPCCommandError.invalidRequest("no active space")
    }

    return id
  }

  /// Resolve an optional zero-based space selector and remove it from command arguments.
  private func targetedRequest(_ request: IPCRequest) throws -> (IPCRequest, UInt64) {
    guard request.args.first == "--space" else {
      return (request, try currentSpaceID())
    }

    guard request.args.count >= 2, let index = Int(request.args[1]), index >= 0 else {
      throw IPCCommandError.invalidRequest("invalid space index")
    }

    let spaceIDs = spaceIDProvider()
    guard spaceIDs.indices.contains(index) else {
      throw IPCCommandError.invalidRequest("space index out of range: \(index)")
    }

    return (
      IPCRequest(
        version: request.version,
        id: request.id,
        domain: request.domain,
        command: request.command,
        args: Array(request.args.dropFirst(2))
      ),
      spaceIDs[index]
    )
  }

  /// Parse a padding change in `mode:top:bottom:left:right` format.
  private func parsePaddingChange(_ argument: String) -> PaddingChange? {
    let parts = argument.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

    guard
      parts.count == 5,
      let mode = NumericChangeMode(rawValue: parts[0])
    else {
      return nil
    }

    guard
      let top = Int(parts[1]),
      let bottom = Int(parts[2]),
      let left = Int(parts[3]),
      let right = Int(parts[4])
    else {
      return nil
    }

    return PaddingChange(
      mode: mode,
      padding: SpacePadding(top: top, bottom: bottom, left: left, right: right)
    )
  }

  /// Parse a gap change in `mode:value` format.
  private func parseGapChange(_ argument: String) -> GapChange? {
    let parts = argument.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

    guard
      parts.count == 2,
      let mode = NumericChangeMode(rawValue: parts[0]),
      let value = Int(parts[1])
    else {
      return nil
    }

    return GapChange(mode: mode, value: value)
  }
}

/// Parsed gap command argument.
private struct GapChange {
  let mode: NumericChangeMode
  let value: Int
}

/// Parsed padding command argument.
private struct PaddingChange {
  let mode: NumericChangeMode
  let padding: SpacePadding
}
