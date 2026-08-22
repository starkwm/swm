import CoreGraphics
import Testing

@testable import SwmLib

@Suite("OrderedWindowLayout")
struct OrderedWindowLayoutTests {
  @Test("insert: places a new window after focus and keeps stable order")
  func insertPlacesWindowAfterFocusAndKeepsStableOrder() {
    var layout = OrderedWindowLayout()

    layout.insert(1, after: nil)
    layout.insert(3, after: nil)
    layout.insert(2, after: 1)
    layout.insert(2, after: 3)
    layout.insert(0, after: 1)

    #expect(layout.windowIDs == [1, 2, 3])
  }

  @Test("remove: removes a retained leaf exactly once")
  func removeRemovesRetainedLeafExactlyOnce() {
    var layout = OrderedWindowLayout()
    layout.insert(1, after: nil)
    layout.insert(2, after: nil)

    let firstRemoval = layout.remove(1)
    let secondRemoval = layout.remove(1)

    #expect(firstRemoval)
    #expect(layout.windowIDs == [2])
    #expect(secondRemoval == false)
  }

  @Test("activeWindowIDs: restores minimized leaves at their retained position")
  func activeWindowIDsRestoresMinimizedLeavesAtRetainedPosition() {
    var layout = OrderedWindowLayout()
    layout.insert(1, after: nil)
    layout.insert(2, after: nil)
    layout.insert(3, after: nil)

    #expect(layout.activeWindowIDs(excluding: [2]) == [1, 3])
    #expect(layout.activeWindowIDs(excluding: []) == [1, 2, 3])
    #expect(layout.windowIDs == [1, 2, 3])
  }
}
