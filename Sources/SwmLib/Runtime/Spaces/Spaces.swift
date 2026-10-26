import AppKit
import CoreGraphics
import StarkSkyLight

/// Owns active Space state, per-Space settings, and runtime topology observations.
@MainActor
public final class Spaces {
  /// Return all known WindowServer spaces.
  static func all() -> [Space] {
    WindowServerClient.shared.allSpaceIDs().map(Space.init(id:))
  }

  /// Return the currently active WindowServer space.
  static func active() -> Space {
    Space(id: WindowServerClient.shared.activeSpace())
  }

  /// Return the display UUID for a space.
  static func display(for space: Space) -> String? {
    WindowServerClient.shared.screenID(for: space.id)
  }

  private static func add(_ value: Int, _ delta: Int, setting: String) throws -> Int {
    let (result, overflow) = value.addingReportingOverflow(delta)
    guard !overflow else {
      throw IPCCommandError.invalidRequest("space \(setting) adjustment overflows integer range")
    }
    return result
  }

  /// ID of the currently active space.
  var currentActiveSpaceID: UInt64? {
    activeSpace.current
  }

  /// ID of the previously active space.
  var lastActiveSpaceID: UInt64? {
    activeSpace.last
  }

  private var activeSpace: TrackedState<UInt64>
  private(set) var defaultSettings = SpaceSettings.defaults
  private var settingsBySpaceID = [UInt64: SpaceSettings]()

  /// Create a Space service seeded from the active space.
  public convenience init() throws {
    _ = try WindowServerClient.spaceClient.get()
    self.init(activeSpaceID: Self.active().id)
  }

  /// Create a Space service with an explicit active space ID.
  init(activeSpaceID: UInt64?) {
    activeSpace = TrackedState(current: activeSpaceID)
  }

  /// Update tracked space state after the active space changes.
  func activeSpaceDidChange(to spaceID: UInt64) {
    activeSpace.update(to: spaceID)
  }

  /// Return layout settings for a space, falling back to defaults.
  func settings(for spaceID: UInt64) -> SpaceSettings {
    settingsBySpaceID[spaceID] ?? defaultSettings
  }

  /// Capture the Space facts needed by one tiling reconciliation.
  func snapshotTopology(
    for windowIDs: [CGWindowID],
    snapshot: () throws -> SpaceSnapshot = { try WindowServerClient.shared.spaceSnapshot() },
    membership: (CGWindowID) throws -> [UInt64] = {
      try WindowServerClient.spaceClient.get().spaceIDs(containing: $0).map(\.rawValue)
    },
    displays: () -> [String: SpaceTopologyDisplay] = {
      Dictionary(
        uniqueKeysWithValues: NSScreen.screens.map {
          ($0.uuid, SpaceTopologyDisplay(visibleFrame: $0.axVisibleFrame))
        }
      )
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
        spaceIDsByWindowID: try Dictionary(
          uniqueKeysWithValues: windowIDs.map { ($0, Set(try membership($0))) }
        ),
        displaysByID: displays()
      )
    } catch {
      log("could not capture Space topology: \(error)", level: .warn)
      return nil
    }
  }

  /// Apply a global configuration change to defaults and existing overrides.
  func updateAllSettings(_ transform: (inout SpaceSettings) throws -> Void) rethrows {
    try transform(&defaultSettings)

    settingsBySpaceID = try settingsBySpaceID.mapValues { currentSettings in
      var settings = currentSettings
      try transform(&settings)
      return settings
    }
  }

  /// Discard overrides for spaces that no longer exist.
  func retainSettings(for spaceIDs: Set<UInt64>) {
    settingsBySpaceID = settingsBySpaceID.filter { spaceIDs.contains($0.key) }
  }

  /// Replace padding for a space, clamping each side to zero or greater.
  @discardableResult
  func setPadding(_ padding: SpacePadding, for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.padding = padding.clamped()
    }
  }

  /// Replace the window gap for a space, clamping it to zero or greater.
  @discardableResult
  func setGap(_ gap: Int, for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.gap = max(0, gap)
    }
  }

  /// Adjust the window gap for a space, clamping it to zero or greater.
  @discardableResult
  func adjustGap(_ gap: Int, for spaceID: UInt64) throws -> SpaceSettings {
    try update(spaceID) { settings in
      settings.gap = max(0, try Self.add(settings.gap, gap, setting: "gap"))
    }
  }

  /// Update stored settings for a space.
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
