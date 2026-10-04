import CoreGraphics
import Testing

@testable import SwmLib

@Suite("ScrollingLayout")
struct ScrollingLayoutTests {
  private enum TestError: Error { case constraint }

  @Test("layout: half-width columns fit exactly with gaps and asymmetric padding")
  func gapsAndPadding() throws {
    let state = state([1, 2])
    let settings = SpaceSettings(
      padding: SpacePadding(top: 10, bottom: 20, left: 30, right: 40),
      gap: 10
    )

    let plan = try plan(state, settings: settings)

    #expect(plan.frames[1] == CGRect(x: 30, y: 10, width: 460, height: 770))
    #expect(plan.frames[2] == CGRect(x: 500, y: 10, width: 460, height: 770))
  }

  @Test("layout: focusing a parked column reveals it with the minimum movement")
  func focusFit() throws {
    let first = try plan(state([1, 2, 3, 4]), focused: 1)
    var state = first.state
    state.reveal = .fit

    let last = try plan(state, focused: 4)

    #expect(last.state.viewportOffset == 1_000)
    #expect(last.frames[4] == CGRect(x: 500, y: 0, width: 500, height: 800))
    #expect(last.frames[3]?.minX == 0)

    state = last.state
    state.reveal = .fit
    let neighbor = try plan(state, focused: 3)
    #expect(neighbor.state.viewportOffset == last.state.viewportOffset)
  }

  @Test("layout: an underfilled strip stays at its current position until explicitly centered")
  func underfilledStrip() throws {
    let plan = try plan(state([1]), focused: 1)

    #expect(plan.state.viewportOffset == 0)
    #expect(plan.frames[1]?.minX == 0)
  }

  @Test("layout: display resizing keeps the focused column within the new viewport")
  func displayResize() throws {
    let before = try plan(state([1, 2, 3]), focused: 3)

    let result = ScrollingLayout().layout(
      state: before.state,
      omittedWindowIDs: [],
      focusedWindowID: 3,
      in: CGRect(x: 0, y: 0, width: 600, height: 800),
      settings: .defaults
    )
    guard case .plan(let after) = result else {
      Issue.record("Expected resized geometry")
      return
    }

    let frame = try #require(after.frames[3])
    #expect(frame.minX >= 0)
    #expect(frame.maxX <= 600)
    #expect(frame.width == 300)
  }

  @Test("layout: respects observed app minimum widths without resizing unrelated columns")
  func minimumWidth() throws {
    let result = ScrollingLayout().layout(
      state: state([1, 2, 3]),
      omittedWindowIDs: [],
      focusedWindowID: 2,
      in: CGRect(x: 0, y: 0, width: 1_000, height: 800),
      settings: .defaults,
      minimumWidths: [2: 600]
    )
    guard case .plan(let plan) = result else {
      Issue.record("Expected constrained app geometry")
      return
    }

    #expect(plan.frames[1]?.width == 500)
    #expect(plan.frames[2]?.width == 600)
    #expect(plan.frames[3]?.width == 500)
    #expect(plan.frames[2]?.maxX == 1_000)
  }

  @Test(
    "layout: centers columns at either end without resizing them",
    arguments: [UInt32(1), UInt32(4)]
  )
  func centersEnds(focused: UInt32) throws {
    var state = state([1, 2, 3, 4])
    state.reveal = .center

    let plan = try plan(state, focused: focused)

    #expect(plan.frames[focused]?.midX == 500)
    #expect(plan.frames[focused]?.width == 500)
  }

  @Test("layout: preserves the viewport anchor when an earlier column closes")
  func removalAnchor() throws {
    let before = try plan(state([1, 2, 3, 4]), focused: 4)
    var state = before.state
    state.reconcile(windowIDs: [2, 3, 4], focusedWindowID: 4, defaultWidth: 0.5)

    let after = try plan(state, focused: 4)

    #expect(after.frames[4] == before.frames[4])
    #expect(after.frames[3] == before.frames[3])
  }

  @Test("layout: omitted columns retain their widths and return to their positions")
  func omittedColumns() throws {
    let state = state([1, 2, 3])

    let omitted = try plan(state, omitted: [2])
    let restored = try plan(omitted.state)

    #expect(omitted.frames[2] == nil)
    #expect(omitted.frames[3]?.minX == 500)
    #expect(restored.frames[2]?.width == 500)
    #expect(restored.frames[3]?.minX == 1_000)
    #expect(restored.state.windowIDs == [1, 2, 3])
  }

  @Test("layout: returns explainable constraints and handles an empty strip")
  func constraintsAndEmpty() throws {
    let layout = ScrollingLayout()
    let zeroBounds = layout.layout(
      state: state([1]),
      omittedWindowIDs: [],
      focusedWindowID: nil,
      in: .zero,
      settings: .defaults
    )
    guard case .insufficientSpace(.usableBounds) = zeroBounds else {
      Issue.record("Expected unusable bounds")
      return
    }

    let hugeGap = layout.layout(
      state: state([1]),
      omittedWindowIDs: [],
      focusedWindowID: nil,
      in: CGRect(x: 0, y: 0, width: 100, height: 100),
      settings: SpaceSettings(padding: .zero, gap: 200)
    )
    guard case .insufficientSpace(.scrollingColumnWidth) = hugeGap else {
      Issue.record("Expected a column width constraint")
      return
    }

    #expect(try plan(state([])).frames.isEmpty)
  }

  private func state(_ ids: [CGWindowID]) -> ScrollingLayoutState {
    var state = ScrollingLayoutState()
    state.reconcile(windowIDs: ids, focusedWindowID: nil, defaultWidth: 0.5)
    return state
  }

  private func plan(
    _ state: ScrollingLayoutState,
    focused: CGWindowID? = nil,
    omitted: Set<CGWindowID> = [],
    settings: SpaceSettings = .defaults
  ) throws -> ScrollingLayoutPlan {
    let result = ScrollingLayout().layout(
      state: state,
      omittedWindowIDs: omitted,
      focusedWindowID: focused,
      in: CGRect(x: 0, y: 0, width: 1_000, height: 800),
      settings: settings
    )
    guard case .plan(let plan) = result else {
      throw TestError.constraint
    }
    return plan
  }

}
