struct SpaceSettings: Equatable {
  static let defaults = SpaceSettings(
    padding: .zero,
    gap: 0
  )

  var padding: SpacePadding

  var gap: Int
}

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

struct SpaceSettingsSnapshot: Equatable {
  let defaults: SpaceSettings
  let bySpaceID: [UInt64: SpaceSettings]
}
