import Testing

@testable import SwmLib

@Suite("SpaceManager")
struct SpaceManagerTests {
  @Test("init: seeds current active space")
  func initSeedsCurrentActiveSpace() {
    let manager = SpaceManager(activeSpaceIDResolver: { 1 })

    #expect(manager.currentActiveSpaceID == 1)
    #expect(manager.lastActiveSpaceID == nil)
  }

  @Test("activeSpaceDidChange: updates current and last space")
  func activeSpaceDidChangeUpdatesCurrentAndLastSpace() {
    let resolver = ActiveSpaceIDSequence([1, 2])
    let manager = SpaceManager(activeSpaceIDResolver: resolver.next)

    manager.activeSpaceDidChange()

    #expect(manager.currentActiveSpaceID == 2)
    #expect(manager.lastActiveSpaceID == 1)
  }

  @Test("activeSpaceDidChange: keeps last space for repeated active space")
  func activeSpaceDidChangeKeepsLastSpaceForRepeatedActiveSpace() {
    let resolver = ActiveSpaceIDSequence([1, 2, 2])
    let manager = SpaceManager(activeSpaceIDResolver: resolver.next)

    manager.activeSpaceDidChange()
    manager.activeSpaceDidChange()

    #expect(manager.currentActiveSpaceID == 2)
    #expect(manager.lastActiveSpaceID == 1)
  }

  @Test("activeSpaceDidChange: ignores nil active space")
  func activeSpaceDidChangeIgnoresNilActiveSpace() {
    let resolver = ActiveSpaceIDSequence([1, nil])
    let manager = SpaceManager(activeSpaceIDResolver: resolver.next)

    manager.activeSpaceDidChange()

    #expect(manager.currentActiveSpaceID == 1)
    #expect(manager.lastActiveSpaceID == nil)
  }

  @Test("settings: returns defaults")
  func settingsReturnsDefaults() {
    let manager = SpaceManager(activeSpaceIDResolver: { nil })
    let settings = manager.settings(for: 1)

    #expect(settings.paddingEnabled)
    #expect(settings.gapEnabled)
    #expect(settings.padding == .zero)
    #expect(settings.gap == 0)
  }

  @Test("toggle: toggles padding and gap booleans")
  func toggleTogglesPaddingAndGapBooleans() {
    let manager = SpaceManager(activeSpaceIDResolver: { nil })

    #expect(manager.togglePadding(for: 1).paddingEnabled == false)
    #expect(manager.togglePadding(for: 1).paddingEnabled)
    #expect(manager.toggleGap(for: 1).gapEnabled == false)
    #expect(manager.toggleGap(for: 1).gapEnabled)
  }

  @Test("padding: applies absolute and relative changes")
  func paddingAppliesAbsoluteAndRelativeChanges() {
    let manager = SpaceManager(activeSpaceIDResolver: { nil })

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

  @Test("gap: applies absolute and relative changes")
  func gapAppliesAbsoluteAndRelativeChanges() {
    let manager = SpaceManager(activeSpaceIDResolver: { nil })

    manager.setGap(5, for: 1)
    let settings = manager.adjustGap(10, for: 1)

    #expect(settings.gap == 15)
  }

  @Test("settings: clamps negative final values")
  func settingsClampsNegativeFinalValues() {
    let manager = SpaceManager(activeSpaceIDResolver: { nil })

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

  @Test("settings: keeps spaces separate")
  func settingsKeepsSpacesSeparate() {
    let manager = SpaceManager(activeSpaceIDResolver: { nil })

    manager.setGap(10, for: 1)
    manager.setGap(20, for: 2)

    #expect(manager.settings(for: 1).gap == 10)
    #expect(manager.settings(for: 2).gap == 20)
  }
}

private final class ActiveSpaceIDSequence: @unchecked Sendable {
  private var values: [UInt64?]

  init(_ values: [UInt64?]) {
    self.values = values
  }

  func next() -> UInt64? {
    guard !values.isEmpty else { return nil }

    return values.removeFirst()
  }
}
