import Testing

@testable import SwmLib

@Suite("SpaceManager")
struct SpaceManagerTests {
  @Test("settings(for:): returns defaults")
  func settingsReturnsDefaults() {
    let manager = SpaceManager()
    let settings = manager.settings(for: 1)

    #expect(settings.paddingEnabled)
    #expect(settings.gapEnabled)
    #expect(settings.padding == .zero)
    #expect(settings.gap == 0)
  }

  @Test("settings(for:): keeps spaces separate")
  func settingsKeepsSpacesSeparate() {
    let manager = SpaceManager()

    manager.setGap(10, for: 1)
    manager.setGap(20, for: 2)

    #expect(manager.settings(for: 1).gap == 10)
    #expect(manager.settings(for: 2).gap == 20)
  }

  @Test("togglePadding(for:): toggles padding boolean")
  func togglePaddingTogglesPaddingBoolean() {
    let manager = SpaceManager()

    #expect(manager.togglePadding(for: 1).paddingEnabled == false)
    #expect(manager.togglePadding(for: 1).paddingEnabled)
  }

  @Test("toggleGap(for:): toggles gap boolean")
  func toggleGapTogglesGapBoolean() {
    let manager = SpaceManager()

    #expect(manager.toggleGap(for: 1).gapEnabled == false)
    #expect(manager.toggleGap(for: 1).gapEnabled)
  }

  @Test("setPadding(_:for:): applies absolute padding")
  func setPaddingAppliesAbsolutePadding() {
    let manager = SpaceManager()

    let settings = manager.setPadding(
      SpacePadding(top: 20, bottom: 20, left: 20, right: 20),
      for: 1
    )

    #expect(settings.padding == SpacePadding(top: 20, bottom: 20, left: 20, right: 20))
  }

  @Test("adjustPadding(_:for:): applies relative padding")
  func adjustPaddingAppliesRelativePadding() {
    let manager = SpaceManager()

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
    let manager = SpaceManager()

    let settings = manager.setGap(5, for: 1)

    #expect(settings.gap == 5)
  }

  @Test("adjustGap(_:for:): applies relative gap")
  func adjustGapAppliesRelativeGap() {
    let manager = SpaceManager()

    manager.setGap(5, for: 1)
    let settings = manager.adjustGap(10, for: 1)

    #expect(settings.gap == 15)
  }

  @Test("adjustGap(_:for:): clamps negative final values")
  func adjustGapClampsNegativeFinalValues() {
    let manager = SpaceManager()

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
