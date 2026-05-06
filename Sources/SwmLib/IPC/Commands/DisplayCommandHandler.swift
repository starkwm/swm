struct DisplayCommandHandler {
  private let displayManager: DisplayManager
  private let displays: () -> [DisplaySerializer]

  init(
    displayManager: DisplayManager = DisplayManager(),
    displays: @escaping () -> [DisplaySerializer] = DisplaySerializer.all
  ) {
    self.displayManager = displayManager
    self.displays = displays
  }

  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "--focus":
        return try focus(request)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported display command: \(request.command)")
      }
    }
  }

  private func focus(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid display focus arguments")
    }

    let target = request.args[0]
    if let message = FocusTargetValidator.validate(
      target: target,
      items: displays(),
      hasRecent: displayManager.lastActiveDisplayID != nil,
      subject: "display"
    ) {
      throw IPCCommandError.invalidRequest(message)
    }

    throw IPCCommandError.unsupportedCommand("display focus is not implemented")
  }
}
