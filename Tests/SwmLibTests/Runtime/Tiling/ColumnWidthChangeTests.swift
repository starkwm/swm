import CoreGraphics
import Testing

@testable import SwmLib

@Suite("ColumnWidthChange")
struct ColumnWidthChangeTests {
  @Test("init(argument:): accepts absolute, relative, and cycling changes")
  func validChanges() {
    #expect(ColumnWidthChange(argument: "abs:0.5") == .absolute(0.5))
    #expect(ColumnWidthChange(argument: "rel:-0.2") == .relative(-0.2))
    #expect(ColumnWidthChange(argument: "next") == .cycle(.next))
    #expect(ColumnWidthChange(argument: "prev") == .cycle(.prev))
  }

  @Test(
    "init(argument:): rejects malformed and nonfinite values",
    arguments: [
      "", "0.5", "abs:", "abs:0.5:1", "rel:nan", "abs:inf", "set:0.5", "rel:wide",
    ]
  )
  func invalidChanges(argument: String) {
    #expect(ColumnWidthChange(argument: argument) == nil)
  }

  @Test("applying(to:): clamps widths and cycles custom widths in both directions")
  func changesAndPresets() {
    #expect(ColumnWidthChange.absolute(2).applying(to: 0.5) == 1)
    #expect(ColumnWidthChange.relative(-1).applying(to: 0.5) == 0.1)
    #expect(ColumnWidthChange.cycle(.next).applying(to: 0.4) == 0.5)
    #expect(ColumnWidthChange.cycle(.prev).applying(to: 0.4) == CGFloat(1.0 / 3))
    #expect(ColumnWidthChange.cycle(.next).applying(to: 1) == CGFloat(1.0 / 3))
    #expect(ColumnWidthChange.cycle(.prev).applying(to: 1.0 / 3) == 1)
  }
}
