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
    switch request.command {
    case "--focus":
      focus(request)
    default:
      .failure(
        id: request.id,
        message: "unsupported display command: \(request.command)",
        errorCode: .unsupportedCommand
      )
    }
  }

  private func focus(_ request: IPCRequest) -> IPCResponse {
    guard request.args.count == 1 else {
      return .failure(
        id: request.id,
        message: "invalid display focus arguments",
        errorCode: .invalidRequest
      )
    }

    let target = request.args[0]
    if let message = FocusTargetValidator.validate(
      target: target,
      items: displays(),
      hasRecent: displayManager.lastActiveDisplayID != nil,
      subject: "display"
    ) {
      return .failure(id: request.id, message: message, errorCode: .invalidRequest)
    }

    return .failure(
      id: request.id,
      message: "display focus is not implemented",
      errorCode: .unsupportedCommand
    )
  }
}
