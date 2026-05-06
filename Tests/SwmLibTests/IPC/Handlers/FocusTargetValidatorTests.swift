import Testing

@testable import SwmLib

@Suite("FocusTargetValidator")
struct FocusTargetValidatorTests {
  @Test("validate: accepts supported targets")
  func validateAcceptsSupportedTargets() {
    let items = [
      FocusItem(index: 2, hasFocus: false),
      FocusItem(index: 0, hasFocus: true),
      FocusItem(index: 1, hasFocus: false),
    ]

    #expect(validate("recent", items: items, hasRecent: true) == nil)
    #expect(validate("prev", items: items) == nil)
    #expect(validate("next", items: items) == nil)
    #expect(validate("1", items: items) == nil)
  }

  @Test("validate: rejects missing recent target")
  func validateRejectsMissingRecentTarget() {
    #expect(validate("recent", hasRecent: false) == "no recent space")
  }

  @Test("validate: rejects adjacent target without focus")
  func validateRejectsAdjacentTargetWithoutFocus() {
    #expect(
      validate(
        "next",
        items: [FocusItem(index: 0, hasFocus: false)],
        subject: "display"
      ) == "no focused display"
    )
  }

  @Test("validate: rejects invalid targets")
  func validateRejectsInvalidTargets() {
    #expect(validate("unknown") == "invalid space focus target: unknown")
    #expect(validate("10") == "space index not found: 10")
  }

  private func validate(
    _ target: String,
    items: [FocusItem] = [FocusItem(index: 0, hasFocus: true)],
    hasRecent: Bool = false,
    subject: String = "space"
  ) -> String? {
    FocusTargetValidator.validate(
      target: target,
      items: items,
      hasRecent: hasRecent,
      subject: subject
    )
  }
}

private struct FocusItem: IndexedFocusItem {
  let index: Int
  let hasFocus: Bool
}
