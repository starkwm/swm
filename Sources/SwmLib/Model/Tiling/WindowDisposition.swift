import CoreGraphics

/// Current automatic-tiling treatment for a managed window.
enum WindowDisposition: Equatable {
  /// Window occupies a retained leaf in one normal Space.
  case tiled

  /// Window remains managed but does not occupy layout geometry.
  case floating(WindowExclusionReason)

  /// Window is outside automatic-tiling management.
  case excluded(WindowExclusionReason)

  /// Window facts are incomplete and will be reconsidered during reconciliation.
  case pending
}

/// Explainable reason a window is not currently tiled.
enum WindowExclusionReason: Equatable {
  /// Window belongs to more than one normal Space.
  case multipleSpaces

  /// Window belongs only to a native fullscreen Space.
  case nativeFullscreen

  /// Accessibility reports a nonstandard window subrole.
  case unsupportedSubrole

  /// Accessibility does not permit position changes.
  case notMovable

  /// Accessibility does not permit size changes.
  case notResizable
}

/// Accessibility and state facts needed to classify one window.
struct TilingWindowSnapshot: Equatable {
  /// Core Graphics window ID.
  let id: CGWindowID

  /// Physical display containing most of the window frame, when known.
  let displayID: String?

  /// Accessibility window subrole.
  let subrole: String?

  /// Whether the window is currently minimized.
  let isMinimized: Bool

  /// Whether Accessibility permits changing the position.
  let isMovable: Bool

  /// Whether Accessibility permits changing the size.
  let isResizable: Bool
}

/// Pure policy for classifying windows against one topology snapshot.
enum WindowEligibilityPolicy {
  /// Return the initial automatic-tiling disposition for a window.
  static func disposition(
    for window: TilingWindowSnapshot,
    topology: SpaceTopology
  ) -> WindowDisposition {
    guard window.subrole == "AXStandardWindow" else {
      return .excluded(.unsupportedSubrole)
    }
    guard window.isMovable else { return .excluded(.notMovable) }
    guard window.isResizable else { return .excluded(.notResizable) }
    guard window.displayID != nil else { return .pending }

    let membership = topology.spaceIDsByWindowID[window.id] ?? []
    let normalSpaceIDs = topology.normalSpaceIDs(for: window.id)

    if normalSpaceIDs.count > 1 {
      return .floating(.multipleSpaces)
    }
    if normalSpaceIDs.count == 1 {
      return .tiled
    }
    if membership.contains(where: { topology.spacesByID[$0]?.type == .fullscreen }) {
      return .excluded(.nativeFullscreen)
    }

    return .pending
  }
}
