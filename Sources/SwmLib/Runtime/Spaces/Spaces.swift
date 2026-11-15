import AppKit
import CoreGraphics
import StarkSkyLight

@MainActor
public final class Spaces {
  static func all(
    in snapshot: SpaceSnapshot? = WindowServerClient.shared.spaceSnapshotIfAvailable()
  ) -> [Space] {
    var seen = Set<UInt64>()
    return (snapshot?.displays ?? []).flatMap(\.spaces).compactMap { space in
      guard seen.insert(space.id.rawValue).inserted else { return nil }
      return Space(id: space.id.rawValue, type: SpaceType(space.type))
    }
  }

  static func active() -> Space? {
    WindowServerClient.shared.activeSpace().map(Space.init(id:))
  }

  static func display(for space: Space) -> String? {
    WindowServerClient.shared.screenID(for: space.id)
  }

  static func topologyDisplays(
    _ displays: [(uuid: String, visibleFrame: CGRect)]
  ) -> [String: SpaceTopologyDisplay] {
    Dictionary(
      displays.map { ($0.uuid, SpaceTopologyDisplay(visibleFrame: $0.visibleFrame)) },
      uniquingKeysWith: { first, _ in first }
    )
  }

  var currentActiveSpaceID: UInt64? {
    activeSpace.current
  }

  var lastActiveSpaceID: UInt64? {
    activeSpace.last
  }

  private(set) var activeSpace: TrackedState<UInt64>
  private(set) var defaultSettings = SpaceSettings.defaults
  private var settingsBySpaceID = [UInt64: SpaceSettings]()
  private let activeSpaceProvider: () -> UInt64?

  public convenience init() throws {
    _ = try WindowServerClient.spaceClient.get()
    let provider = { WindowServerClient.shared.activeSpace() }
    self.init(activeSpaceID: provider(), activeSpaceProvider: provider)
  }

  init(activeSpaceID: UInt64?, activeSpaceProvider: @escaping () -> UInt64? = { nil }) {
    activeSpace = TrackedState(current: activeSpaceID)
    self.activeSpaceProvider = activeSpaceProvider
  }

  func activeSpaceDidChange(to spaceID: UInt64) {
    activeSpace.update(to: spaceID)
  }

  func activeSpaceBecameUnavailable() {
    activeSpace.invalidate()
  }

  func restoreActiveSpace(_ spaceID: UInt64) {
    guard activeSpace.current == nil else { return }
    activeSpace.update(to: spaceID)
  }

  func resolveActiveSpaceID() -> UInt64? {
    if let id = activeSpace.current { return id }
    guard let id = activeSpaceProvider() else { return nil }

    activeSpace.update(to: id)
    return id
  }

  func settings(for spaceID: UInt64) -> SpaceSettings {
    settingsBySpaceID[spaceID] ?? defaultSettings
  }

  func snapshotTopology(
    for windowIDs: [CGWindowID],
    snapshot: () throws -> SpaceSnapshot = { try WindowServerClient.shared.spaceSnapshot() },
    membership: (CGWindowID) throws -> [UInt64] = {
      try WindowServerClient.spaceClient.get().spaceIDs(containing: $0).map(\.rawValue)
    },
    displays: () -> [String: SpaceTopologyDisplay] = {
      Spaces.topologyDisplays(NSScreen.screens.map { ($0.uuid, $0.axVisibleFrame) })
    }
  ) -> SpaceTopology? {
    do {
      let snapshot = try snapshot()
      guard snapshot.isComplete else { return nil }
      var spacesByID = [UInt64: SpaceTopologyDescriptor]()
      var visibleSpaceIDByDisplayID = [String: UInt64]()
      for display in snapshot.displays {
        visibleSpaceIDByDisplayID[display.id.rawValue] = display.currentSpaceID?.rawValue
        for space in display.spaces {
          spacesByID[space.id.rawValue] = SpaceTopologyDescriptor(
            id: space.id.rawValue,
            displayID: display.id.rawValue,
            type: SpaceType(space.type)
          )
        }
      }
      return SpaceTopology(
        spacesByID: spacesByID,
        visibleSpaceIDByDisplayID: visibleSpaceIDByDisplayID,
        spaceIDsByWindowID: Dictionary(
          windowIDs.map { windowID in
            do {
              return (windowID, Set(try membership(windowID)))
            } catch {
              log("could not read Space membership for window \(windowID): \(error)", level: .warn)
              return (windowID, [])
            }
          },
          uniquingKeysWith: { first, _ in first }
        ),
        displaysByID: displays(),
        activeSpaceID: snapshot.activeSpaceID?.rawValue
      )
    } catch {
      log("could not capture Space topology: \(error)", level: .warn)
      return nil
    }
  }

  func updateAllSettings(_ transform: (inout SpaceSettings) throws -> Void) rethrows {
    try transform(&defaultSettings)

    settingsBySpaceID = try settingsBySpaceID.mapValues { currentSettings in
      var settings = currentSettings
      try transform(&settings)
      return settings
    }
  }

  func settingsSnapshot() -> SpaceSettingsSnapshot {
    SpaceSettingsSnapshot(defaults: defaultSettings, bySpaceID: settingsBySpaceID)
  }

  func restoreSettings(_ snapshot: SpaceSettingsSnapshot) {
    defaultSettings = snapshot.defaults
    settingsBySpaceID = snapshot.bySpaceID
  }

  func retainSettings(for spaceIDs: Set<UInt64>) {
    settingsBySpaceID = settingsBySpaceID.filter { spaceIDs.contains($0.key) }
  }

  @discardableResult
  func setPadding(_ padding: SpacePadding, for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.padding = padding.clamped()
    }
  }

  @discardableResult
  func setGap(_ gap: Int, for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.gap = max(0, gap)
    }
  }

  private func update(
    _ spaceID: UInt64,
    transform: (inout SpaceSettings) throws -> Void
  ) rethrows -> SpaceSettings {
    var settings = settingsBySpaceID[spaceID] ?? defaultSettings
    try transform(&settings)
    settingsBySpaceID[spaceID] = settings
    return settings
  }
}
