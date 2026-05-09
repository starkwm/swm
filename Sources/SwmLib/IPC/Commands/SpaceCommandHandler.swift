/// Handles IPC commands that update the active space.
struct SpaceCommandHandler {
  private let spaceManager: SpaceManager

  /// Create a space command handler backed by a space manager.
  init(spaceManager: SpaceManager) {
    self.spaceManager = spaceManager
  }

  /// Dispatch a space IPC request to the matching active-space update.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "--toggle":
        return try toggle(request)
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
    case "gap":
      let spaceID = try currentSpaceID()
      spaceManager.toggleGap(for: spaceID)
    default:
      throw IPCCommandError.invalidRequest("invalid space toggle target: \(target)")
    }

    return .success(id: request.id, message: "ok")
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

/// A parsed gap command argument.
private struct GapChange {
  let mode: ChangeMode
  let value: Int
}

/// A parsed padding command argument.
private struct PaddingChange {
  let mode: ChangeMode
  let padding: SpacePadding
}
