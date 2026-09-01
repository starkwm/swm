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

/// Tracks the current and previous active display.
@MainActor
public final class Displays {
  /// Display ID for the currently active display.
  var currentActiveDisplayID: String? {
    activeDisplay.current
  }

  /// Display ID for the previously active display.
  var lastActiveDisplayID: String? {
    activeDisplay.last
  }

  private var activeDisplay: TrackedState<String>

  /// Create a display observation seeded from the active space.
  public init() {
    activeDisplay = TrackedState(current: Spaces.display(for: Spaces.active()))
  }

  /// Start observing CoreGraphics display reconfiguration callbacks.
  public func start() -> Result<Void, DisplaysError> {
    let result = CGDisplayRegisterReconfigurationCallback(
      displayReconfigurationCallback,
      Unmanaged.passUnretained(self).toOpaque()
    )

    return result == .success
      ? .success(()) : .failure(.accessFailed("failed to register display callback: \(result)"))
  }

  /// Update tracked display state after the active space changes.
  func activeDisplayDidChange() {
    guard let activeDisplayID = Spaces.display(for: Spaces.active()) else { return }
    activeDisplay.update(to: activeDisplayID)
  }

  /// Publish display events for CoreGraphics reconfiguration flags.
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

/// Errors raised while starting display observation.
public enum DisplaysError: Error, CustomStringConvertible {
  /// Display observation could not be started or accessed.
  case accessFailed(String)

  /// Human-readable display observation failure description.
  public var description: String {
    switch self {
    case .accessFailed(let message):
      return message
    }
  }
}
