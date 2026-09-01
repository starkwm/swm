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
    let spaces = Spaces()
    let settings = spaces.settings(for: 1)

    #expect(settings.paddingEnabled)
    #expect(settings.gapEnabled)
    #expect(settings.padding == .zero)
    #expect(settings.gap == 0)
  }

  @Test("settings(for:): keeps spaces separate")
  func settingsKeepsSpacesSeparate() {
    let spaces = Spaces()

    spaces.setGap(10, for: 1)
    spaces.setGap(20, for: 2)

    #expect(spaces.settings(for: 1).gap == 10)
    #expect(spaces.settings(for: 2).gap == 20)
  }

  @Test("retainSettings(for:): removes stale overrides")
  func retainSettingsRemovesStaleOverrides() {
    let spaces = Spaces()
    spaces.updateAllSettings { $0.gap = 5 }
    spaces.setGap(10, for: 1)
    spaces.setGap(20, for: 2)

    spaces.retainSettings(for: [2])

    #expect(spaces.settings(for: 1).gap == 5)
    #expect(spaces.settings(for: 2).gap == 20)
  }

  @Test("togglePadding(for:): toggles padding boolean")
  func togglePaddingTogglesPaddingBoolean() {
    let spaces = Spaces()

    #expect(spaces.togglePadding(for: 1).paddingEnabled == false)
    #expect(spaces.togglePadding(for: 1).paddingEnabled)
  }

  @Test("toggleGap(for:): toggles gap boolean")
  func toggleGapTogglesGapBoolean() {
    let spaces = Spaces()

    #expect(spaces.toggleGap(for: 1).gapEnabled == false)
    #expect(spaces.toggleGap(for: 1).gapEnabled)
  }

  @Test("setPadding(_:for:): applies absolute padding")
  func setPaddingAppliesAbsolutePadding() {
    let spaces = Spaces()

    let settings = spaces.setPadding(
      SpacePadding(top: 20, bottom: 20, left: 20, right: 20),
      for: 1
    )

    #expect(settings.padding == SpacePadding(top: 20, bottom: 20, left: 20, right: 20))
  }

  @Test("adjustPadding(_:for:): applies relative padding")
  func adjustPaddingAppliesRelativePadding() {
    let spaces = Spaces()

    spaces.setPadding(
      SpacePadding(top: 20, bottom: 20, left: 20, right: 20),
      for: 1
    )
    let settings = spaces.adjustPadding(
      SpacePadding(top: 10, bottom: 0, left: -5, right: -5),
      for: 1
    )

    #expect(settings.padding == SpacePadding(top: 30, bottom: 20, left: 15, right: 15))
  }

  @Test("setGap(_:for:): applies absolute gap")
  func setGapAppliesAbsoluteGap() {
    let spaces = Spaces()

    let settings = spaces.setGap(5, for: 1)

    #expect(settings.gap == 5)
  }

  @Test("adjustGap(_:for:): applies relative gap")
  func adjustGapAppliesRelativeGap() {
    let spaces = Spaces()

    spaces.setGap(5, for: 1)
    let settings = spaces.adjustGap(10, for: 1)

    #expect(settings.gap == 15)
  }

  @Test("adjustGap(_:for:): clamps negative final values")
  func adjustGapClampsNegativeFinalValues() {
    let spaces = Spaces()

    spaces.setPadding(
      SpacePadding(top: -1, bottom: 1, left: -2, right: 2),
      for: 1
    )
    spaces.adjustPadding(
      SpacePadding(top: -10, bottom: -10, left: -10, right: -10),
      for: 1
    )
    spaces.setGap(-1, for: 1)

    let settings = spaces.adjustGap(-10, for: 1)

    #expect(settings.padding == .zero)
    #expect(settings.gap == 0)
  }
}
