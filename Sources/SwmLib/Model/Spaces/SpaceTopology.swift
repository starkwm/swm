import CoreGraphics

/// Immutable facts used by one Space reconciliation pass.
struct SpaceTopology: Equatable {
  /// WindowServer Spaces keyed by their runtime IDs.
  let spacesByID: [UInt64: SpaceTopologyDescriptor]

  /// Currently visible Space ID for each WindowServer display identifier.
  let visibleSpaceIDByDisplayID: [String: UInt64]

  /// Complete Space membership for each managed window.
  let spaceIDsByWindowID: [CGWindowID: Set<UInt64>]

  /// Attached physical displays keyed by Core Graphics UUID.
  let displaysByID: [String: SpaceTopologyDisplay]

  /// Normal Spaces that are currently visible on at least one WindowServer display.
  var visibleNormalSpaceIDs: Set<UInt64> {
    Set(visibleSpaceIDByDisplayID.values.filter { spacesByID[$0]?.type == .normal })
  }

  /// Normal Space membership for a managed window.
  func normalSpaceIDs(for windowID: CGWindowID) -> Set<UInt64> {
    Set((spaceIDsByWindowID[windowID] ?? []).filter { spacesByID[$0]?.type == .normal })
  }
}

/// WindowServer description of one Space at snapshot time.
struct SpaceTopologyDescriptor: Equatable {
  /// WindowServer Space ID.
  let id: UInt64

  /// WindowServer display identifier that owns the Space.
  let displayID: String

  /// WindowServer Space type.
  let type: SpaceType
}

/// Physical display geometry captured alongside Space facts.
struct SpaceTopologyDisplay: Equatable {
  /// Core Graphics display UUID.
  let id: String

  /// Visible frame in Accessibility coordinates.
  let visibleFrame: CGRect
}
