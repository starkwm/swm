import Testing

@testable import SwmLib

@Suite("Spaces")
@MainActor
struct SpacesTests {
  @Test("activeSpaceDidChange(to:): uses event space ID")
  func activeSpaceDidChangeUsesEventSpaceID() {
    let spaces = Spaces(activeSpaceID: 1)

    spaces.activeSpaceDidChange(to: 2)

    #expect(spaces.currentActiveSpaceID == 2)
    #expect(spaces.lastActiveSpaceID == 1)
  }

  @Test("settings(for:): returns defaults")
  func settingsReturnsDefaults() {
    let spaces = Spaces(activeSpaceID: nil)
    let settings = spaces.settings(for: 1)

    #expect(settings.padding == .zero)
    #expect(settings.gap == 0)
  }

  @Test("settings(for:): keeps spaces separate")
  func settingsKeepsSpacesSeparate() {
    let spaces = Spaces(activeSpaceID: nil)

    spaces.setGap(10, for: 1)
    spaces.setGap(20, for: 2)

    #expect(spaces.settings(for: 1).gap == 10)
    #expect(spaces.settings(for: 2).gap == 20)
  }

  @Test("retainSettings(for:): removes stale overrides")
  func retainSettingsRemovesStaleOverrides() {
    let spaces = Spaces(activeSpaceID: nil)
    spaces.updateAllSettings { $0.gap = 5 }
    spaces.setGap(10, for: 1)
    spaces.setGap(20, for: 2)

    spaces.retainSettings(for: [2])

    #expect(spaces.settings(for: 1).gap == 5)
    #expect(spaces.settings(for: 2).gap == 20)
  }

  @Test("adjustPadding(_:for:): applies relative padding")
  func adjustPaddingAppliesRelativePadding() throws {
    let spaces = Spaces(activeSpaceID: nil)

    spaces.setPadding(
      SpacePadding(top: 20, bottom: 20, left: 20, right: 20),
      for: 1
    )
    #expect(
      spaces.settings(for: 1).padding == SpacePadding(top: 20, bottom: 20, left: 20, right: 20)
    )
    let settings = try spaces.adjustPadding(
      SpacePadding(top: 10, bottom: 0, left: -5, right: -5),
      for: 1
    )

    #expect(settings.padding == SpacePadding(top: 30, bottom: 20, left: 15, right: 15))
    #expect(spaces.settings(for: 2) == .defaults)
  }

  @Test("setGap(_:for:): applies absolute gap")
  func setGapAppliesAbsoluteGap() {
    let spaces = Spaces(activeSpaceID: nil)

    let settings = spaces.setGap(5, for: 1)

    #expect(settings.gap == 5)
  }

  @Test("adjustGap(_:for:): applies relative gap")
  func adjustGapAppliesRelativeGap() throws {
    let spaces = Spaces(activeSpaceID: nil)

    spaces.setGap(5, for: 1)
    let settings = try spaces.adjustGap(10, for: 1)

    #expect(settings.gap == 15)
  }

  @Test("adjustGap(_:for:): clamps negative final values")
  func adjustGapClampsNegativeFinalValues() throws {
    let spaces = Spaces(activeSpaceID: nil)

    spaces.setPadding(
      SpacePadding(top: -1, bottom: 1, left: -2, right: 2),
      for: 1
    )
    try spaces.adjustPadding(
      SpacePadding(top: -10, bottom: -10, left: -10, right: -10),
      for: 1
    )
    spaces.setGap(-1, for: 1)

    let settings = try spaces.adjustGap(-10, for: 1)

    #expect(settings.padding == .zero)
    #expect(settings.gap == 0)
  }

  @Test("relative gap rejects overflow in defaults and overrides", arguments: [false, true])
  func gapOverflow(existingOverride: Bool) throws {
    let spaces = Spaces(activeSpaceID: nil)
    spaces.updateAllSettings { $0.gap = Int.max }
    if existingOverride { spaces.setGap(Int.max, for: 1) }
    let previous = spaces.settings(for: 1)

    #expect(throws: IPCCommandError.invalidRequest("space gap adjustment overflows integer range"))
    {
      try spaces.adjustGap(1, for: 1)
    }
    #expect(spaces.settings(for: 1) == previous)
    spaces.retainSettings(for: [])
    #expect(spaces.settings(for: 1) == previous)
    #expect(try spaces.adjustGap(Int.min, for: 1).gap == 0)
    #expect(try spaces.adjustGap(Int.max, for: 1).gap == Int.max)
  }

  @Test("relative padding rejects overflow on every side atomically", arguments: 0..<4)
  func paddingOverflow(side: Int) throws {
    let spaces = Spaces(activeSpaceID: nil)
    let original = SpacePadding(top: Int.max, bottom: Int.max, left: Int.max, right: Int.max)
    spaces.setPadding(original, for: 1)
    let delta = SpacePadding(
      top: side == 0 ? 1 : -1,
      bottom: side == 1 ? 1 : -1,
      left: side == 2 ? 1 : -1,
      right: side == 3 ? 1 : -1
    )

    #expect(
      throws: IPCCommandError.invalidRequest("space padding adjustment overflows integer range")
    ) {
      try spaces.adjustPadding(delta, for: 1)
    }
    #expect(spaces.settings(for: 1).padding == original)
    #expect(spaces.settings(for: 2) == .defaults)
    let reduced = try spaces.adjustPadding(
      SpacePadding(top: Int.min, bottom: -1, left: 0, right: -Int.max),
      for: 1
    )
    #expect(reduced.padding == SpacePadding(top: 0, bottom: Int.max - 1, left: Int.max, right: 0))
  }
}
