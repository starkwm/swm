import CoreGraphics

private func displayReconfigurationCallback(
  displayID: CGDirectDisplayID,
  flags: CGDisplayChangeSummaryFlags,
  userInfo: UnsafeMutableRawPointer?
) {
  guard let userInfo else { return }

  let displays = Unmanaged<Displays>.fromOpaque(userInfo).takeUnretainedValue()
  Task { @MainActor in
    displays.displayReconfiguration(displayID: displayID, flags: flags)
  }
}

@MainActor
public final class Displays {
  var currentActiveDisplayID: String? {
    activeDisplay.current
  }

  var lastActiveDisplayID: String? {
    activeDisplay.last
  }

  private(set) var activeDisplay: TrackedState<String>

  public init() {
    activeDisplay = TrackedState(current: Spaces.active().flatMap(Spaces.display(for:)))
  }

  public func observe() -> Result<Void, DisplaysError> {
    let result = CGDisplayRegisterReconfigurationCallback(
      displayReconfigurationCallback,
      Unmanaged.passUnretained(self).toOpaque()
    )

    return result == .success
      ? .success(()) : .failure(.accessFailed("failed to register display callback: \(result)"))
  }

  func activeDisplayDidChange() {
    guard let activeDisplayID = Spaces.active().flatMap(Spaces.display(for:)) else { return }
    activeDisplay.update(to: activeDisplayID)
  }

  func displayReconfiguration(
    displayID: CGDirectDisplayID,
    flags: CGDisplayChangeSummaryFlags
  ) {
    if flags.contains(.addFlag) {
      Events.shared.post(.display(.added(displayID)))
    }

    if flags.contains(.removeFlag) {
      Events.shared.post(.display(.removed(displayID)))
    }

    if flags.contains(.movedFlag) {
      Events.shared.post(.display(.moved(displayID)))
    }

    if flags.contains(.desktopShapeChangedFlag) {
      Events.shared.post(.display(.resized(displayID)))
    }
  }
}

public enum DisplaysError: Error, CustomStringConvertible {
  case accessFailed(String)

  public var description: String {
    switch self {
    case .accessFailed(let message):
      return message
    }
  }
}
