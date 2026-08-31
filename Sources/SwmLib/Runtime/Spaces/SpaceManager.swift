import AppKit
import CoreGraphics

/// Owns active Space state, per-Space settings, and runtime topology observations.
@MainActor
public final class SpaceManager {
  /// Return all known WindowServer spaces.
  nonisolated static func all() -> [Space] {
    WindowServerClient.shared.allSpaceIDs().map(Space.init(id:))
  }

  /// Return the currently active WindowServer space.
  nonisolated static func active() -> Space {
    Space(id: WindowServerClient.shared.activeSpace())
  }

  /// Return the display UUID for a space.
  nonisolated static func display(for space: Space) -> String? {
    WindowServerClient.shared.screenID(for: space.id)
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

  /// Create a space manager seeded from the active space.
  public convenience init() {
    self.init(activeSpaceID: Self.active().id)
  }

  /// Create a space manager with an explicit active space ID.
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

  /// Toggle whether padding is applied on a space.
  @discardableResult
  func togglePadding(for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.paddingEnabled.toggle()
    }
  }

  /// Toggle whether gaps are applied on a space.
  @discardableResult
  func toggleGap(for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.gapEnabled.toggle()
    }
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
  func adjustPadding(_ padding: SpacePadding, for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.padding = SpacePadding(
        top: settings.padding.top + padding.top,
        bottom: settings.padding.bottom + padding.bottom,
        left: settings.padding.left + padding.left,
        right: settings.padding.right + padding.right
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
  func adjustGap(_ gap: Int, for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.gap = max(0, settings.gap + gap)
    }
  }

  /// Update stored settings for a space.
  private func update(
    _ spaceID: UInt64,
    transform: (inout SpaceSettings) -> Void
  ) -> SpaceSettings {
    var settings = settingsBySpaceID[spaceID] ?? defaultSettings
    transform(&settings)
    settingsBySpaceID[spaceID] = settings
    return settings
  }
}

/// Per-side padding applied inside a space's visible frame.
struct SpacePadding: Equatable {
  /// Padding with every side set to zero.
  static let zero = SpacePadding(top: 0, bottom: 0, left: 0, right: 0)

  /// Top padding in points.
  var top: Int

  /// Bottom padding in points.
  var bottom: Int

  /// Left padding in points.
  var left: Int

  /// Right padding in points.
  var right: Int

  /// Return padding with every side clamped to zero or greater.
  func clamped() -> SpacePadding {
    SpacePadding(
      top: max(0, top),
      bottom: max(0, bottom),
      left: max(0, left),
      right: max(0, right)
    )
  }
}

/// Layout settings applied when placing windows on a space.
struct SpaceSettings: Equatable {
  /// Default settings used for spaces without explicit overrides.
  static let defaults = SpaceSettings(
    paddingEnabled: true,
    gapEnabled: true,
    padding: .zero,
    gap: 0
  )

  /// Whether padding should affect layout calculations.
  var paddingEnabled: Bool

  /// Whether gaps should affect layout calculations.
  var gapEnabled: Bool

  /// Padding around the usable area.
  var padding: SpacePadding

  /// Gap between grid cells in points.
  var gap: Int
}
