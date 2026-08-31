import CoreGraphics
import Testing

@testable import SwmLib

@Suite("WindowDisplayTransfer")
struct WindowDisplayTransferTests {
  @Test("targetWindowFrame: preserves relative placement")
  func targetWindowFramePreservesRelativePlacement() {
    let transfer = WindowDisplayTransfer(
      windowFrame: CGRect(x: 400, y: 200, width: 400, height: 300),
      sourceFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
      targetFrame: CGRect(x: 1200, y: 0, width: 1600, height: 1200)
    )

    expect(
      transfer.targetWindowFrame(),
      equals: CGRect(x: 1800, y: 300, width: 400, height: 300)
    )
  }

  @Test("targetWindowFrame: shrinks to fit target")
  func targetWindowFrameShrinksToFitTarget() {
    let transfer = WindowDisplayTransfer(
      windowFrame: CGRect(x: 0, y: 0, width: 900, height: 700),
      sourceFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
      targetFrame: CGRect(x: 1200, y: 0, width: 800, height: 600)
    )

    expect(
      transfer.targetWindowFrame(),
      equals: CGRect(x: 1200, y: 0, width: 800, height: 600)
    )
  }

  @Test("targetWindowFrame: shrinks to target visible frame below menu bar")
  func targetWindowFrameShrinksToTargetVisibleFrameBelowMenuBar() {
    let transfer = WindowDisplayTransfer(
      windowFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
      sourceFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
      targetFrame: CGRect(x: 1200, y: 24, width: 1200, height: 876)
    )

    expect(
      transfer.targetWindowFrame(),
      equals: CGRect(x: 1200, y: 24, width: 1200, height: 876)
    )
  }

  @Test("targetWindowFrame: uses source visible frame below menu bar")
  func targetWindowFrameUsesSourceVisibleFrameBelowMenuBar() {
    let transfer = WindowDisplayTransfer(
      windowFrame: CGRect(x: 0, y: 312, width: 400, height: 300),
      sourceFrame: CGRect(x: 0, y: 24, width: 1200, height: 876),
      targetFrame: CGRect(x: 1200, y: 0, width: 1200, height: 900)
    )

    expect(
      transfer.targetWindowFrame(),
      equals: CGRect(x: 1200, y: 300, width: 400, height: 300)
    )
  }

  @Test("targetWindowFrame: clamps offscreen source placement")
  func targetWindowFrameClampsOffscreenSourcePlacement() {
    let transfer = WindowDisplayTransfer(
      windowFrame: CGRect(x: -200, y: 1000, width: 400, height: 300),
      sourceFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
      targetFrame: CGRect(x: 1200, y: 0, width: 1600, height: 1200)
    )

    expect(
      transfer.targetWindowFrame(),
      equals: CGRect(x: 1200, y: 900, width: 400, height: 300)
    )
  }

  private func expect(_ actual: CGRect, equals expected: CGRect) {
    #expect(abs(actual.origin.x - expected.origin.x) < 0.0001)
    #expect(abs(actual.origin.y - expected.origin.y) < 0.0001)
    #expect(abs(actual.size.width - expected.size.width) < 0.0001)
    #expect(abs(actual.size.height - expected.size.height) < 0.0001)
  }
}
