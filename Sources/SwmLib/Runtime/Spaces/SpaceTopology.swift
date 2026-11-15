import CoreGraphics

struct SpaceTopology: Equatable {
  let spacesByID: [UInt64: SpaceTopologyDescriptor]

  let visibleSpaceIDByDisplayID: [String: UInt64]

  let spaceIDsByWindowID: [CGWindowID: Set<UInt64>]

  let displaysByID: [String: SpaceTopologyDisplay]

  var activeSpaceID: UInt64? = nil

  var layoutIDs: Set<TilingLayoutID> {
    Set(
      spacesByID.values
        .filter { $0.type == .normal }
        .flatMap { layoutIDs(spaceID: $0.id, windowServerDisplayID: $0.displayID) }
    )
  }

  var visibleLayoutIDs: Set<TilingLayoutID> {
    Set(
      visibleSpaceIDByDisplayID.flatMap { displayID, spaceID in
        guard spacesByID[spaceID]?.type == .normal else { return [TilingLayoutID]() }
        return layoutIDs(spaceID: spaceID, windowServerDisplayID: displayID)
      }
    )
  }

  private var windowServerDisplayIDs: Set<String> {
    Set(spacesByID.values.map(\.displayID))
      .union(visibleSpaceIDByDisplayID.keys)
  }

  func normalSpaceIDs(for windowID: CGWindowID) -> Set<UInt64> {
    Set((spaceIDsByWindowID[windowID] ?? []).filter { spacesByID[$0]?.type == .normal })
  }

  func layoutID(for windowID: CGWindowID, on displayID: String?) -> TilingLayoutID? {
    guard let displayID, displaysByID[displayID] != nil else { return nil }
    let normalSpaceIDs = normalSpaceIDs(for: windowID)
    guard normalSpaceIDs.count == 1, let spaceID = normalSpaceIDs.first else { return nil }
    let layoutID = TilingLayoutID(spaceID: spaceID, displayID: displayID)
    return layoutIDs.contains(layoutID) ? layoutID : nil
  }

  private func layoutIDs(
    spaceID: UInt64,
    windowServerDisplayID: String
  ) -> [TilingLayoutID] {
    if displaysByID[windowServerDisplayID] != nil {
      return [TilingLayoutID(spaceID: spaceID, displayID: windowServerDisplayID)]
    }

    guard windowServerDisplayIDs == [windowServerDisplayID] else { return [] }
    return displaysByID.keys.map { TilingLayoutID(spaceID: spaceID, displayID: $0) }
  }
}

struct SpaceTopologyDescriptor: Equatable {
  let id: UInt64

  let displayID: String

  let type: SpaceType
}

struct SpaceTopologyDisplay: Equatable {
  let visibleFrame: CGRect
}
