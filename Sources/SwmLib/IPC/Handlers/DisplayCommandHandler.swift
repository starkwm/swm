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
      return invalid(request, "invalid display focus arguments")
    }

    let target = request.args[0]

    switch target {
    case "recent":
      guard displayManager.lastActiveDisplayID != nil else {
        return invalid(request, "no recent display")
      }

    case "prev", "next":
      let arrangedDisplays = displays().sorted { $0.index < $1.index }

      guard let currentDisplay = arrangedDisplays.first(where: \.hasFocus) else {
        return invalid(request, "no focused display")
      }

      guard
        adjacentDisplay(
          from: currentDisplay.index,
          direction: target,
          displays: arrangedDisplays
        ) != nil
      else {
        return invalid(request, "no focused display")
      }

    default:
      guard let index = Int(target) else {
        return invalid(request, "invalid display focus target: \(target)")
      }

      guard displays().contains(where: { $0.index == index }) else {
        return invalid(request, "display index not found: \(index)")
      }
    }

    return .failure(
      id: request.id,
      message: "display focus is not implemented",
      errorCode: .unsupportedCommand
    )
  }

  private func adjacentDisplay(
    from currentIndex: Int,
    direction: String,
    displays arrangedDisplays: [DisplaySerializer]
  ) -> DisplaySerializer? {
    guard
      !arrangedDisplays.isEmpty,
      let currentPosition = arrangedDisplays.firstIndex(where: { $0.index == currentIndex })
    else {
      return nil
    }

    let offset = direction == "prev" ? -1 : 1
    let nextPosition = (currentPosition + offset + arrangedDisplays.count) % arrangedDisplays.count

    return arrangedDisplays[nextPosition]
  }

  private func invalid(_ request: IPCRequest, _ message: String) -> IPCResponse {
    .failure(id: request.id, message: message, errorCode: .invalidRequest)
  }
}
