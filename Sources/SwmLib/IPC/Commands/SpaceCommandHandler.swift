struct SpaceCommandHandler {
  private let spaceManager: SpaceManager
  private let spaces: () -> [SpaceSerializer]

  init(
    spaceManager: SpaceManager,
    spaces: @escaping () -> [SpaceSerializer] = {
      SpaceSerializer.all(windowManager: WindowManager(workspace: Workspace()))
    }
  ) {
    self.spaceManager = spaceManager
    self.spaces = spaces
  }

  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "--toggle":
        return try toggle(request)
      case "--padding":
        return try padding(request)
      case "--gap":
        return try gap(request)
      case "--focus":
        return try focus(request)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported space command: \(request.command)")
      }
    }
  }

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

  private func focus(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid space focus arguments")
    }

    let target = request.args[0]
    if let message = FocusTargetValidator.validate(
      target: target,
      items: spaces(),
      hasRecent: spaceManager.lastActiveSpaceID != nil,
      subject: "space"
    ) {
      throw IPCCommandError.invalidRequest(message)
    }

    throw IPCCommandError.unsupportedCommand("space focus is not implemented")
  }

  private func currentSpaceID() throws -> UInt64 {
    guard let id = spaceManager.currentActiveSpaceID else {
      throw IPCCommandError.invalidRequest("no active space")
    }

    return id
  }

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

private struct GapChange {
  let mode: ChangeMode
  let value: Int
}

private struct PaddingChange {
  let mode: ChangeMode
  let padding: SpacePadding
}
