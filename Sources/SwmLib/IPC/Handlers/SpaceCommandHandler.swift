import Foundation

struct SpaceCommandHandler {
  private let spaceManager: SpaceManager
  private let activeSpaceID: () -> UInt64
  private let spaces: () -> [SpaceSerializer]

  init(
    spaceManager: SpaceManager = SpaceManager(),
    activeSpaceID: @escaping () -> UInt64 = { Space.active().id },
    spaces: @escaping () -> [SpaceSerializer] = {
      SpaceSerializer.all(windowManager: WindowManager(workspace: Workspace()))
    }
  ) {
    self.spaceManager = spaceManager
    self.activeSpaceID = activeSpaceID
    self.spaces = spaces
  }

  func dispatch(_ request: IPCRequest) -> IPCResponse {
    switch request.command {
    case "--toggle":
      return toggle(request, spaceID: activeSpaceID())
    case "--padding":
      return padding(request, spaceID: activeSpaceID())
    case "--gap":
      return gap(request, spaceID: activeSpaceID())
    case "--focus":
      return focus(request)
    default:
      return .failure(
        id: request.id,
        message: "unsupported space command: \(request.command)",
        errorCode: .unsupportedCommand
      )
    }
  }

  private func toggle(_ request: IPCRequest, spaceID: UInt64) -> IPCResponse {
    guard request.args.count == 1 else {
      return invalid(request, "invalid space toggle arguments")
    }

    let settings: SpaceSettings
    switch request.args[0] {
    case "padding":
      settings = spaceManager.togglePadding(for: spaceID)
    case "gap":
      settings = spaceManager.toggleGap(for: spaceID)
    default:
      return invalid(request, "invalid space toggle target: \(request.args[0])")
    }

    return success(request, spaceID: spaceID, settings: settings)
  }

  private func focus(_ request: IPCRequest) -> IPCResponse {
    guard request.args.count == 1 else {
      return invalid(request, "invalid space focus arguments")
    }

    let target = request.args[0]

    switch target {
    case "recent":
      guard spaceManager.lastActiveSpaceID != nil else {
        return invalid(request, "no recent space")
      }

    case "prev", "next":
      let arrangedSpaces = spaces().sorted { $0.index < $1.index }

      guard let currentSpace = arrangedSpaces.first(where: \.hasFocus) else {
        return invalid(request, "no focused space")
      }

      guard
        adjacentSpace(
          from: currentSpace.index,
          direction: target,
          spaces: arrangedSpaces
        ) != nil
      else {
        return invalid(request, "no focused space")
      }

    default:
      guard let index = Int(target) else {
        return invalid(request, "invalid space focus target: \(target)")
      }

      guard spaces().contains(where: { $0.index == index }) else {
        return invalid(request, "space index not found: \(index)")
      }
    }

    return .failure(
      id: request.id,
      message: "space focus is not implemented",
      errorCode: .unsupportedCommand
    )
  }

  private func padding(_ request: IPCRequest, spaceID: UInt64) -> IPCResponse {
    guard request.args.count == 1 else {
      return invalid(request, "invalid space padding arguments")
    }

    guard let change = parsePaddingChange(request.args[0]) else {
      return invalid(request, "invalid space padding value: \(request.args[0])")
    }

    let settings =
      switch change.mode {
      case .absolute:
        spaceManager.setPadding(change.padding, for: spaceID)
      case .relative:
        spaceManager.adjustPadding(change.padding, for: spaceID)
      }

    return success(request, spaceID: spaceID, settings: settings)
  }

  private func gap(_ request: IPCRequest, spaceID: UInt64) -> IPCResponse {
    guard request.args.count == 1 else {
      return invalid(request, "invalid space gap arguments")
    }

    guard let change = parseGapChange(request.args[0]) else {
      return invalid(request, "invalid space gap value: \(request.args[0])")
    }

    let settings =
      switch change.mode {
      case .absolute:
        spaceManager.setGap(change.value, for: spaceID)
      case .relative:
        spaceManager.adjustGap(change.value, for: spaceID)
      }

    return success(request, spaceID: spaceID, settings: settings)
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

  private func adjacentSpace(
    from currentIndex: Int,
    direction: String,
    spaces arrangedSpaces: [SpaceSerializer]
  ) -> SpaceSerializer? {
    guard
      !arrangedSpaces.isEmpty,
      let currentPosition = arrangedSpaces.firstIndex(where: { $0.index == currentIndex })
    else {
      return nil
    }

    let offset = direction == "prev" ? -1 : 1
    let nextPosition = (currentPosition + offset + arrangedSpaces.count) % arrangedSpaces.count

    return arrangedSpaces[nextPosition]
  }

  private func success(
    _ request: IPCRequest,
    spaceID: UInt64,
    settings: SpaceSettings
  ) -> IPCResponse {
    let result = SpaceResultSerializer(
      id: spaceID,
      paddingEnabled: settings.paddingEnabled,
      gapEnabled: settings.gapEnabled,
      padding: SpacePaddingSerializer(
        top: settings.padding.top,
        bottom: settings.padding.bottom,
        left: settings.padding.left,
        right: settings.padding.right
      ),
      gap: settings.gap
    )

    do {
      let data = try JSONEncoder().encode(result)

      guard let message = String(data: data, encoding: .utf8) else {
        return .failure(
          id: request.id,
          message: "could not encode space settings",
          errorCode: .internalError
        )
      }

      return .success(id: request.id, message: message)
    } catch {
      return .failure(
        id: request.id,
        message: "could not encode space settings: \(error)",
        errorCode: .internalError
      )
    }
  }

  private func invalid(_ request: IPCRequest, _ message: String) -> IPCResponse {
    .failure(id: request.id, message: message, errorCode: .invalidRequest)
  }
}

private struct SpaceResultSerializer: Encodable {
  enum CodingKeys: String, CodingKey {
    case id
    case paddingEnabled = "padding-enabled"
    case gapEnabled = "gap-enabled"
    case padding
    case gap
  }

  let id: UInt64
  let paddingEnabled: Bool
  let gapEnabled: Bool
  let padding: SpacePaddingSerializer
  let gap: Int
}

private struct SpacePaddingSerializer: Encodable {
  let top: Int
  let bottom: Int
  let left: Int
  let right: Int
}
