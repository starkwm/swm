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

  private var windowServerDisplayIDs: Set<String> {
    Set(spacesByID.values.map(\.displayID))
      .union(visibleSpaceIDByDisplayID.keys)
  }

  /// Every normal Space and physical display pair available for tiling.
  var layoutIDs: Set<SpaceLayoutID> {
    Set(
      spacesByID.values
        .filter { $0.type == .normal }
        .flatMap { layoutIDs(spaceID: $0.id, windowServerDisplayID: $0.displayID) }
    )
  }

  /// Every visible normal Space and physical display pair available for tiling.
  var visibleLayoutIDs: Set<SpaceLayoutID> {
    Set(
      visibleSpaceIDByDisplayID.flatMap { displayID, spaceID in
        guard spacesByID[spaceID]?.type == .normal else { return [SpaceLayoutID]() }
        return layoutIDs(spaceID: spaceID, windowServerDisplayID: displayID)
      }
    )
  }

  /// Normal Space membership for a managed window.
  func normalSpaceIDs(for windowID: CGWindowID) -> Set<UInt64> {
    Set((spaceIDsByWindowID[windowID] ?? []).filter { spacesByID[$0]?.type == .normal })
  }

  /// Resolve an eligible window to its Space and physical display layout.
  func layoutID(for windowID: CGWindowID, on displayID: String?) -> SpaceLayoutID? {
    guard let displayID, displaysByID[displayID] != nil else { return nil }
    let normalSpaceIDs = normalSpaceIDs(for: windowID)
    guard normalSpaceIDs.count == 1, let spaceID = normalSpaceIDs.first else { return nil }
    let layoutID = SpaceLayoutID(spaceID: spaceID, displayID: displayID)
    return layoutIDs.contains(layoutID) ? layoutID : nil
  }

  private func layoutIDs(
    spaceID: UInt64,
    windowServerDisplayID: String
  ) -> [SpaceLayoutID] {
    if displaysByID[windowServerDisplayID] != nil {
      return [SpaceLayoutID(spaceID: spaceID, displayID: windowServerDisplayID)]
    }

    // Without separate Spaces, WindowServer reports one logical display group for every screen.
    guard windowServerDisplayIDs == [windowServerDisplayID] else { return [] }
    return displaysByID.keys.map { SpaceLayoutID(spaceID: spaceID, displayID: $0) }
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
  /// Visible frame in Accessibility coordinates.
  let visibleFrame: CGRect
}
