import Foundation

struct SpacePadding: Equatable {
  var top: Int
  var bottom: Int
  var left: Int
  var right: Int

  static let zero = SpacePadding(top: 0, bottom: 0, left: 0, right: 0)

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
  var paddingEnabled: Bool
  var gapEnabled: Bool
  var padding: SpacePadding
  var gap: Int

  static let `default` = SpaceSettings(
    paddingEnabled: true,
    gapEnabled: true,
    padding: .zero,
    gap: 0
  )
}

public final class SpaceManager {
  private let lock = NSLock()
  private var settingsBySpaceID = [UInt64: SpaceSettings]()

  public init() {}

  func settings(for spaceID: UInt64) -> SpaceSettings {
    lock.withLock {
      settingsBySpaceID[spaceID] ?? .default
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
      var settings = settingsBySpaceID[spaceID] ?? .default
      transform(&settings)
      settingsBySpaceID[spaceID] = settings
      return settings
    }
  }
}

extension SpaceManager: @unchecked Sendable {}
