import Testing

@testable import SwmLib

@Suite("Spaces")
@MainActor
struct SpacesTests {
  @Test(
    "activeSpaceDidChange: keeps the previous distinct Space across repeated events",
    arguments: [nil, 1] as [UInt64?]
  )
  func activeSpaceDidChangeKeepsThePreviousDistinctSpaceAcrossRepeatedEvents(initialID: UInt64?) {
    let spaces = Spaces(activeSpaceID: initialID)

    spaces.activeSpaceDidChange(to: 2)

    #expect(spaces.currentActiveSpaceID == 2)
    #expect(spaces.lastActiveSpaceID == initialID)

    spaces.activeSpaceDidChange(to: 2)
    #expect(spaces.lastActiveSpaceID == initialID)

    spaces.activeSpaceDidChange(to: 3)
    spaces.activeSpaceDidChange(to: 3)
    #expect(spaces.currentActiveSpaceID == 3)
    #expect(spaces.lastActiveSpaceID == 2)
  }

  @Test("adjustPadding: rejects overflow on every side atomically", arguments: 0..<4)
  func adjustPaddingRejectsOverflowOnEverySideAtomically(side: Int) throws {
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

  @Test("adjustGap: clamps negative final values")
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

  @Test("adjustGap: rejects overflow in defaults and overrides", arguments: [false, true])
  func adjustGapRejectsOverflowInDefaultsAndOverrides(existingOverride: Bool) throws {
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
}
