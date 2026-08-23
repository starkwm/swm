/// Handles IPC commands that update the active space.
@MainActor
struct SpaceCommandHandler {
  private let spaceManager: SpaceManager
  private let tilingManager: TilingManager

  /// Create a space command handler backed by space and tiling managers.
  init(spaceManager: SpaceManager, tilingManager: TilingManager) {
    self.spaceManager = spaceManager
    self.tilingManager = tilingManager
  }

  /// Dispatch a space IPC request to the matching active-space update.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "--toggle":
        return try toggle(request)
      case "--layout":
        return try layout(request)
      case "--padding":
        return try padding(request)
      case "--gap":
        return try gap(request)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported space command: \(request.command)")
      }
    }
  }

  /// Toggle padding or gap behavior for the active space.
  private func toggle(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid space toggle arguments")
    }

    let target = request.args[0]

    switch target {
    case "padding":
      let spaceID = try currentSpaceID()
      spaceManager.togglePadding(for: spaceID)
      tilingManager.reflow(spaceID: spaceID)
    case "gap":
      let spaceID = try currentSpaceID()
      spaceManager.toggleGap(for: spaceID)
      tilingManager.reflow(spaceID: spaceID)
    case "tiling":
      let spaceID = try currentSpaceID()
      guard let enabled = tilingManager.toggleEnabled(for: spaceID) else {
        throw IPCCommandError.invalidRequest("automatic tiling unavailable for active space")
      }
      return .success(id: request.id, message: enabled ? "on" : "off")
    default:
      throw IPCCommandError.invalidRequest("invalid space toggle target: \(target)")
    }

    return .success(id: request.id, message: "ok")
  }

  /// Select the automatic layout for the active Space.
  private func layout(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid space layout arguments")
    }

    let argument = request.args[0]
    let mode: LayoutMode

    switch argument {
    case "master":
      mode = .master
    case "dwindle":
      mode = .dwindle
    default:
      throw IPCCommandError.invalidRequest("invalid space layout: \(argument)")
    }

    let spaceID = try currentSpaceID()
    guard tilingManager.setLayoutMode(mode, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for active space")
    }

    return .success(id: request.id, message: mode.rawValue)
  }

  /// Set or adjust padding for the active space.
  private func padding(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid space padding arguments")
    }

    guard let change = parsePaddingChange(request.args[0]) else {
      throw IPCCommandError.invalidRequest("invalid space padding value: \(request.args[0])")
    }

    let spaceID = try currentSpaceID()

    switch change.mode {
    case .absolute:
      spaceManager.setPadding(change.padding, for: spaceID)
    case .relative:
      spaceManager.adjustPadding(change.padding, for: spaceID)
    }

    tilingManager.reflow(spaceID: spaceID)

    return .success(id: request.id, message: "ok")
  }

  /// Set or adjust the window gap for the active space.
  private func gap(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid space gap arguments")
    }

    guard let change = parseGapChange(request.args[0]) else {
      throw IPCCommandError.invalidRequest("invalid space gap value: \(request.args[0])")
    }

    let spaceID = try currentSpaceID()

    switch change.mode {
    case .absolute:
      spaceManager.setGap(change.value, for: spaceID)
    case .relative:
      spaceManager.adjustGap(change.value, for: spaceID)
    }

    tilingManager.reflow(spaceID: spaceID)

    return .success(id: request.id, message: "ok")
  }

  /// Return the currently active space ID.
  private func currentSpaceID() throws -> UInt64 {
    guard let id = spaceManager.currentActiveSpaceID else {
      throw IPCCommandError.invalidRequest("no active space")
    }

    return id
  }

  /// Parse a padding change in `mode:top:bottom:left:right` format.
  private func parsePaddingChange(_ argument: String) -> PaddingChange? {
    let parts = argument.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

    guard
      parts.count == 5,
      let mode = ChangeMode(rawValue: parts[0])
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
      let mode = ChangeMode(rawValue: parts[0]),
      let value = Int(parts[1])
    else {
      return nil
    }

    return GapChange(mode: mode, value: value)
  }
}

/// Parsed gap command argument.
private struct GapChange {
  let mode: ChangeMode
  let value: Int
}

/// Parsed padding command argument.
private struct PaddingChange {
  let mode: ChangeMode
  let padding: SpacePadding
}
