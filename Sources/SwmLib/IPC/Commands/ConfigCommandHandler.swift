struct ConfigCommandHandler {
  private let spaceManager: SpaceManager
  private let spaces: () -> [Space]

  init(
    spaceManager: SpaceManager,
    spaces: @escaping () -> [Space] = SpaceManager.all
  ) {
    self.spaceManager = spaceManager
    self.spaces = spaces
  }

  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
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

  private func windowGap(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid config window-gap arguments")
    }

    guard let gap = Int(request.args[0]) else {
      throw IPCCommandError.invalidRequest("invalid config window-gap value: \(request.args[0])")
    }

    for space in spaces() {
      spaceManager.setGap(gap, for: space.id)
    }

    return .success(id: request.id, message: "ok")
  }

  private func padding(_ request: IPCRequest, side: PaddingSide) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid config \(request.command) arguments")
    }

    guard let value = Int(request.args[0]) else {
      throw IPCCommandError.invalidRequest(
        "invalid config \(request.command) value: \(request.args[0])"
      )
    }

    for space in spaces() {
      var padding = spaceManager.settings(for: space.id).padding

      switch side {
      case .top:
        padding.top = value
      case .bottom:
        padding.bottom = value
      case .left:
        padding.left = value
      case .right:
        padding.right = value
      }

      spaceManager.setPadding(padding, for: space.id)
    }

    return .success(id: request.id, message: "ok")
  }
}

private enum PaddingSide {
  case top
  case bottom
  case left
  case right
}
