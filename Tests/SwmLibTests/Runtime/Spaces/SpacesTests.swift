import Testing

@testable import SwmLib

@Suite("Spaces")
@MainActor
struct SpaceManagerTests {
  @Test("activeSpaceDidChange(to:): uses event space ID")
  func activeSpaceDidChangeUsesEventSpaceID() {
    let manager = Spaces(activeSpaceID: 1)

    manager.activeSpaceDidChange(to: 2)

    #expect(manager.currentActiveSpaceID == 2)
    #expect(manager.lastActiveSpaceID == 1)
  }

  @Test("settings(for:): returns defaults")
  func settingsReturnsDefaults() {
    let manager = Spaces()
    let settings = manager.settings(for: 1)

    #expect(settings.paddingEnabled)
    #expect(settings.gapEnabled)
    #expect(settings.padding == .zero)
    #expect(settings.gap == 0)
  }

  @Test("settings(for:): keeps spaces separate")
  func settingsKeepsSpacesSeparate() {
    let manager = Spaces()

    manager.setGap(10, for: 1)
    manager.setGap(20, for: 2)

    #expect(manager.settings(for: 1).gap == 10)
    #expect(manager.settings(for: 2).gap == 20)
  }

  @Test("retainSettings(for:): removes stale overrides")
  func retainSettingsRemovesStaleOverrides() {
    let manager = Spaces()
    manager.updateAllSettings { $0.gap = 5 }
    manager.setGap(10, for: 1)
    manager.setGap(20, for: 2)

    manager.retainSettings(for: [2])

    #expect(manager.settings(for: 1).gap == 5)
    #expect(manager.settings(for: 2).gap == 20)
  }

  @Test("togglePadding(for:): toggles padding boolean")
  func togglePaddingTogglesPaddingBoolean() {
    let manager = Spaces()

    #expect(manager.togglePadding(for: 1).paddingEnabled == false)
    #expect(manager.togglePadding(for: 1).paddingEnabled)
  }

  @Test("toggleGap(for:): toggles gap boolean")
  func toggleGapTogglesGapBoolean() {
    let manager = Spaces()

    #expect(manager.toggleGap(for: 1).gapEnabled == false)
    #expect(manager.toggleGap(for: 1).gapEnabled)
  }

  @Test("setPadding(_:for:): applies absolute padding")
  func setPaddingAppliesAbsolutePadding() {
    let manager = Spaces()

    let settings = manager.setPadding(
      SpacePadding(top: 20, bottom: 20, left: 20, right: 20),
      for: 1
    )

    #expect(settings.padding == SpacePadding(top: 20, bottom: 20, left: 20, right: 20))
  }

  @Test("adjustPadding(_:for:): applies relative padding")
  func adjustPaddingAppliesRelativePadding() {
    let manager = Spaces()

    manager.setPadding(
      SpacePadding(top: 20, bottom: 20, left: 20, right: 20),
      for: 1
    )
    let settings = manager.adjustPadding(
      SpacePadding(top: 10, bottom: 0, left: -5, right: -5),
      for: 1
    )

    #expect(settings.padding == SpacePadding(top: 30, bottom: 20, left: 15, right: 15))
  }

  @Test("setGap(_:for:): applies absolute gap")
  func setGapAppliesAbsoluteGap() {
    let manager = Spaces()

    let settings = manager.setGap(5, for: 1)

    #expect(settings.gap == 5)
  }

  @Test("adjustGap(_:for:): applies relative gap")
  func adjustGapAppliesRelativeGap() {
    let manager = Spaces()

    manager.setGap(5, for: 1)
    let settings = manager.adjustGap(10, for: 1)

    #expect(settings.gap == 15)
  }

  @Test("adjustGap(_:for:): clamps negative final values")
  func adjustGapClampsNegativeFinalValues() {
    let manager = Spaces()

    manager.setPadding(
      SpacePadding(top: -1, bottom: 1, left: -2, right: 2),
      for: 1
    )
    manager.adjustPadding(
      SpacePadding(top: -10, bottom: -10, left: -10, right: -10),
      for: 1
    )
    manager.setGap(-1, for: 1)

    let settings = manager.adjustGap(-10, for: 1)

    #expect(settings.padding == .zero)
    #expect(settings.gap == 0)
  }
}
