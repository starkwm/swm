/// Handles IPC commands that update the selected space.
@MainActor
struct SpaceCommandHandler {
  private let spaces: Spaces
  private let tiling: Tiling
  private let spaceIDProvider: () -> [UInt64]
  private let activateSpace: (Int) async throws -> Void
  private let arguments = SettingArguments(scope: "space")

  /// Create a space command handler backed by space and tiling services.
  init(
    spaces: Spaces,
    tiling: Tiling,
    spaceIDProvider: @escaping () -> [UInt64] = { Spaces.all().map(\.id) },
    activateSpace: @escaping (Int) async throws -> Void = { _ in
      throw SpaceActivationBridgeError.unavailable
    }
  ) {
    self.spaces = spaces
    self.tiling = tiling
    self.spaceIDProvider = spaceIDProvider
    self.activateSpace = activateSpace
  }

  /// Dispatch a space IPC request to the matching selected-space update.
  func dispatch(_ request: IPCRequest) async -> IPCResponse {
    await IPCCommandError.catching(id: request.id) {
      if request.command == "--activate" {
        let argument = try IPCArguments(request.args, context: "space activate").requiredValue()
        guard let index = Int(argument), index > 0 else {
          throw IPCCommandError.invalidRequest("invalid space index: \(argument)")
        }
        try await activateSpace(index)
        return .acknowledged(id: request.id)
      }

      let operation: (IPCRequest, UInt64) throws -> IPCResponse

      switch request.command {
      case "--layout":
        operation = layout
      case "--master-ratio":
        operation = masterRatio
      case "--master-placement":
        operation = masterPlacement
      case "--split-ratio":
        operation = splitRatio
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
      if targetedRequest.args.isEmpty {
        return .success(
          id: request.id,
          message: try currentValue(of: request.command, for: spaceID)
        )
      }
      return try operation(targetedRequest, spaceID)
    }
  }

  /// The selected Space's current value of a setting, in the form its command accepts.
  private func currentValue(of command: String, for spaceID: UInt64) throws -> String {
    let setting = String(command.dropFirst(2))
    if let value = SettingArguments.currentValue(of: setting, in: spaces.settings(for: spaceID)) {
      return value
    }

    guard let state = tiling.layoutState(for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    guard let value = SettingArguments.currentValue(of: setting, in: state) else {
      throw IPCCommandError.unsupportedCommand("unsupported space command: \(command)")
    }
    return value
  }

  /// Set or adjust the master pane ratio for the selected Space.
  private func masterRatio(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse {
    let change = try arguments.ratioChange(request.args, setting: "master-ratio")
    guard tiling.changeMasterRatio(change, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return .acknowledged(id: request.id)
  }

  /// Set or adjust the dwindle split ratio for the selected Space, rebalancing its splits.
  private func splitRatio(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse {
    let change = try arguments.ratioChange(request.args, setting: "split-ratio")
    guard tiling.changeSplitRatio(change, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return .acknowledged(id: request.id)
  }

  /// Set or cycle the master pane edge for the selected Space.
  private func masterPlacement(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse {
    let placement: MasterPlacement?
    switch try arguments.masterPlacement(request.args) {
    case .set(let selectedPlacement):
      placement =
        tiling.setMasterPlacement(selectedPlacement, for: spaceID) ? selectedPlacement : nil
    case .cycle(let direction):
      placement = tiling.cycleMasterPlacement(direction, for: spaceID)
    }
    guard let placement else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return .success(id: request.id, message: placement.rawValue)
  }

  /// Set whether dwindle branches preserve their resolved direction on the selected Space.
  private func preserveSplitDirections(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse
  {
    let enabled = try arguments.preserveSplit(request.args)
    guard tiling.setSplitDirectionPreservation(enabled, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return .success(id: request.id, message: enabled ? "on" : "off")
  }

  /// Select floating or automatic layout for the selected Space.
  private func layout(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse {
    let selection = try arguments.layout(request.args)
    guard tiling.setLayout(selection, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }

    return .success(id: request.id, message: selection.rawValue)
  }

  /// Set or adjust padding sides for the selected space, keeping sides left out.
  private func padding(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse {
    let padding = try PaddingSideChange.applying(
      arguments.paddingChanges(request.args),
      to: spaces.settings(for: spaceID).padding,
      context: "space padding"
    )
    spaces.setPadding(padding, for: spaceID)
    tiling.reflow(spaceID: spaceID)

    return .acknowledged(id: request.id)
  }

  /// Set or adjust the window gap for the selected space.
  private func gap(_ request: IPCRequest, spaceID: UInt64) throws -> IPCResponse {
    let gap = try arguments.gap(request.args, current: spaces.settings(for: spaceID).gap)
    spaces.setGap(gap, for: spaceID)
    tiling.reflow(spaceID: spaceID)

    return .acknowledged(id: request.id)
  }

  /// Return the currently active space ID.
  private func currentSpaceID() throws -> UInt64 {
    guard let id = spaces.resolveActiveSpaceID() else {
      throw IPCCommandError.invalidRequest("no active space")
    }

    return id
  }

  /// Resolve an optional one-based space selector and remove it from command arguments.
  private func targetedRequest(_ request: IPCRequest) throws -> (IPCRequest, UInt64) {
    guard request.args.first == "--space" else {
      return (request, try currentSpaceID())
    }

    guard request.args.count >= 2, let index = Int(request.args[1]), index > 0 else {
      throw IPCCommandError.invalidRequest("invalid space index")
    }

    let spaceIDs = spaceIDProvider()
    guard spaceIDs.indices.contains(index - 1) else {
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
      spaceIDs[index - 1]
    )
  }
}
