import Foundation

struct SpacePadding: Equatable {
  static let zero = SpacePadding(top: 0, bottom: 0, left: 0, right: 0)

  var top: Int
  var bottom: Int
  var left: Int
  var right: Int

  func clamped() -> SpacePadding {
    SpacePadding(
      top: max(0, top),
      bottom: max(0, bottom),
      left: max(0, left),
      right: max(0, right)
    )
  }
}

struct SpaceSettings: Equatable {
  static let defaults = SpaceSettings(
    paddingEnabled: true,
    gapEnabled: true,
    padding: .zero,
    gap: 0
  )

  var paddingEnabled: Bool
  var gapEnabled: Bool
  var padding: SpacePadding
  var gap: Int
}

public final class SpaceManager {
  private static func resolveActiveSpaceID() -> UInt64? {
    Space.active().id
  }

  public var currentActiveSpaceID: UInt64? {
    lock.withLock {
      activeSpaceState.current
    }
  }

  public var lastActiveSpaceID: UInt64? {
    lock.withLock {
      activeSpaceState.last
    }
  }

  private let lock = NSLock()

  private var activeSpaceState: ActiveSpaceState
  private var settingsBySpaceID = [UInt64: SpaceSettings]()

  public init() {
    activeSpaceState = ActiveSpaceState(
      current: Self.resolveActiveSpaceID(),
      last: nil
    )
  }

  func activeSpaceDidChange() {
    guard let activeSpaceID = Self.resolveActiveSpaceID() else { return }

    lock.withLock {
      guard activeSpaceID != activeSpaceState.current else { return }

      activeSpaceState = ActiveSpaceState(
        current: activeSpaceID,
        last: activeSpaceState.current
      )
    }
  }

  func settings(for spaceID: UInt64) -> SpaceSettings {
    lock.withLock {
      settingsBySpaceID[spaceID] ?? .defaults
    }
  }

  @discardableResult
  func togglePadding(for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.paddingEnabled.toggle()
    }
  }

  @discardableResult
  func toggleGap(for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.gapEnabled.toggle()
    }
  }

  @discardableResult
  func setPadding(_ padding: SpacePadding, for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.padding = padding.clamped()
    }
  }

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

  @discardableResult
  func setGap(_ gap: Int, for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.gap = max(0, gap)
    }
  }

  @discardableResult
  func adjustGap(_ gap: Int, for spaceID: UInt64) -> SpaceSettings {
    update(spaceID) { settings in
      settings.gap = max(0, settings.gap + gap)
    }
  }

  private func update(
    _ spaceID: UInt64,
    transform: (inout SpaceSettings) -> Void
  ) -> SpaceSettings {
    lock.withLock {
      var settings = settingsBySpaceID[spaceID] ?? .defaults
      transform(&settings)
      settingsBySpaceID[spaceID] = settings
      return settings
    }
  }
}

extension SpaceManager: @unchecked Sendable {}

private struct ActiveSpaceState {
  var current: UInt64?
  var last: UInt64?
}
