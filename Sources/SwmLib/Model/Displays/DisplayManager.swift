import CoreGraphics

private func displayReconfigurationCallback(
  displayID: CGDirectDisplayID,
  flags: CGDisplayChangeSummaryFlags,
  userInfo: UnsafeMutableRawPointer?
) {
  guard let userInfo else { return }

  let displayManager = Unmanaged<DisplayManager>.fromOpaque(userInfo).takeUnretainedValue()
  Task { @MainActor in
    displayManager.displayReconfiguration(displayID: displayID, flags: flags)
  }
}

/// Tracks the current and previous active display.
@MainActor
public final class DisplayManager {
  /// Display ID for the currently active display.
  var currentActiveDisplayID: String? {
    activeDisplay.current
  }

  /// Display ID for the previously active display.
  var lastActiveDisplayID: String? {
    activeDisplay.last
  }

  private var activeDisplay: TrackedState<String>

  /// Create a display manager seeded from the active space.
  public init() {
    activeDisplay = TrackedState(current: SpaceManager.display(for: SpaceManager.active()))
  }

  /// Start observing CoreGraphics display reconfiguration callbacks.
  public func start() -> Result<Void, DisplayManagerError> {
    let result = CGDisplayRegisterReconfigurationCallback(
      displayReconfigurationCallback,
      Unmanaged.passUnretained(self).toOpaque()
    )

    return result == .success
      ? .success(()) : .failure(.accessFailed("failed to register display callback: \(result)"))
  }

  /// Update tracked display state after the active space changes.
  func activeDisplayDidChange() {
    guard let activeDisplayID = SpaceManager.display(for: SpaceManager.active()) else { return }
    activeDisplay.update(to: activeDisplayID)
  }

  /// Publish display events for CoreGraphics reconfiguration flags.
  func displayReconfiguration(
    displayID: CGDirectDisplayID,
    flags: CGDisplayChangeSummaryFlags
  ) {
    if flags.contains(.addFlag) {
      EventManager.shared.post(.display(.added(displayID)))
    }

    if flags.contains(.removeFlag) {
      EventManager.shared.post(.display(.removed(displayID)))
    }

    if flags.contains(.movedFlag) {
      EventManager.shared.post(.display(.moved(displayID)))
    }

    if flags.contains(.desktopShapeChangedFlag) {
      EventManager.shared.post(.display(.resized(displayID)))
    }
  }
}

/// Errors raised while starting display observation.
public enum DisplayManagerError: Error, CustomStringConvertible {
  /// Display observation could not be started or accessed.
  case accessFailed(String)

  /// Human-readable display manager failure description.
  public var description: String {
    switch self {
    case .accessFailed(let message):
      return message
    }
  }
}
