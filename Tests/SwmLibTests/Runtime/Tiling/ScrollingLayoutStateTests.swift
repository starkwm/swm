import Testing

@testable import SwmLib

@Suite("ScrollingLayoutState")
struct ScrollingLayoutStateTests {
  @Test("reconcile: preserves widths and inserts new columns after focus")
  func focusedInsertion() {
    var state = ScrollingLayoutState()
    state.reconcile(windowIDs: [1, 2, 3], focusedWindowID: nil, defaultWidth: 0.5)
    state.columns[1].width = 1

    state.reconcile(windowIDs: [1, 2, 3, 4, 5], focusedWindowID: 2, defaultWidth: 0.333)

    #expect(state.windowIDs == [1, 2, 4, 5, 3])
    #expect(state.columns.map(\.width) == [0.5, 1, 0.333, 0.333, 0.5])
  }

  @Test("reconcile: removes closed windows without changing surviving columns")
  func removal() {
    var state = ScrollingLayoutState()
    state.reconcile(windowIDs: [1, 2, 3], focusedWindowID: nil, defaultWidth: 0.5)

    state.reconcile(windowIDs: [1, 3], focusedWindowID: 2, defaultWidth: 1)

    #expect(state.windowIDs == [1, 3])
    #expect(state.columns.map(\.width) == [0.5, 0.5])
  }

  @Test("swap: moves width with its column and rejects missing windows")
  func columnSwap() {
    var state = ScrollingLayoutState()
    state.columns = [
      ScrollingColumn(windowID: 1, width: 0.5), ScrollingColumn(windowID: 2, width: 1),
    ]

    let swapped = state.swap(1, with: 2)

    #expect(swapped)
    #expect(
      state.columns == [
        ScrollingColumn(windowID: 2, width: 1), ScrollingColumn(windowID: 1, width: 0.5),
      ]
    )
    let missing = state.swap(1, with: 99)
    #expect(!missing)
  }
}
