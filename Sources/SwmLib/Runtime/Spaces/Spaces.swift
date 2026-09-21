import AppKit
import CoreGraphics

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
  private var defaultSettings = SpaceSettings.defaults
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
  func snapshotTopology(for windowIDs: [CGWindowID]) -> SpaceTopology {
    let displaySpaces = WindowServerClient.shared.displaySpaces()
    let spacesByID = Dictionary(
      uniqueKeysWithValues: displaySpaces.flatMap { display in
        display.spaces.map { spaceID in
          (
            spaceID,
            SpaceTopologyDescriptor(
              id: spaceID,
              displayID: display.id,
              type: WindowServerClient.shared.spaceType(for: spaceID)
            )
          )
        }
      }
    )
    let visibleSpaceIDByDisplayID = Dictionary(
      uniqueKeysWithValues: displaySpaces.compactMap { display in
        let spaceID = WindowServerClient.shared.currentSpace(for: display.id)
        return spaceID == 0 ? nil : (display.id, spaceID)
      }
    )
    let spaceIDsByWindowID = Dictionary(
      uniqueKeysWithValues: windowIDs.map { windowID in
        (windowID, Set(WindowServerClient.shared.spaceIDs(containing: windowID)))
      }
    )

    return SpaceTopology(
      spacesByID: spacesByID,
      visibleSpaceIDByDisplayID: visibleSpaceIDByDisplayID,
      spaceIDsByWindowID: spaceIDsByWindowID,
      displaysByID: Dictionary(
        uniqueKeysWithValues: NSScreen.screens.map { screen in
          (screen.uuid, SpaceTopologyDisplay(visibleFrame: screen.axVisibleFrame))
        }
      )
    )
  }

  /// Apply a global configuration change to defaults and existing overrides.
  func updateAllSettings(_ transform: (inout SpaceSettings) -> Void) {
    transform(&defaultSettings)

    settingsBySpaceID = settingsBySpaceID.mapValues { currentSettings in
      var settings = currentSettings
      transform(&settings)
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

  /// Adjust padding for a space, clamping each side to zero or greater.
  @discardableResult
  func adjustPadding(_ padding: SpacePadding, for spaceID: UInt64) throws -> SpaceSettings {
    try update(spaceID) { settings in
      settings.padding = SpacePadding(
        top: try Self.add(settings.padding.top, padding.top, setting: "padding"),
        bottom: try Self.add(settings.padding.bottom, padding.bottom, setting: "padding"),
        left: try Self.add(settings.padding.left, padding.left, setting: "padding"),
        right: try Self.add(settings.padding.right, padding.right, setting: "padding")
      )
      .clamped()
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
