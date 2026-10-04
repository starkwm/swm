import CoreGraphics

/// Retained columns and viewport for one scrolling Space and display.
struct ScrollingLayoutState {
  private(set) var isInitialized = false
  var columns = [ScrollingColumn]()
  var viewportOffset: CGFloat = 0
  var anchorWindowID: CGWindowID?
  var anchorPosition: CGFloat = 0
  var reveal: ScrollingFocusFit? = .fit

  var windowIDs: [CGWindowID] { columns.map(\.windowID) }

  /// Keep existing widths and order, inserting new columns after the focused window.
  mutating func reconcile(
    windowIDs: [CGWindowID],
    focusedWindowID: CGWindowID?,
    defaultWidth: CGFloat
  ) {
    isInitialized = true
    let desired = Set(windowIDs)
    columns.removeAll { !desired.contains($0.windowID) }
    let retained = Set(self.windowIDs)
    var anchor = focusedWindowID

    for windowID in windowIDs where !retained.contains(windowID) {
      let index = anchor.flatMap { id in columns.firstIndex { $0.windowID == id } }
      columns.insert(
        ScrollingColumn(windowID: windowID, width: defaultWidth),
        at: index.map { $0 + 1 } ?? columns.endIndex
      )
      anchor = windowID
    }
  }

  /// Move the complete column, including its width, to another column's position.
  mutating func swap(_ windowID: CGWindowID, with neighborID: CGWindowID) -> Bool {
    guard let source = columns.firstIndex(where: { $0.windowID == windowID }),
      let target = columns.firstIndex(where: { $0.windowID == neighborID })
    else { return false }

    columns.swapAt(source, target)
    return true
  }
}

/// One window per column in the initial scrolling layout.
struct ScrollingColumn: Equatable {
  let windowID: CGWindowID
  var width: CGFloat
}

/// How keyboard or application focus brings a column into view.
enum ScrollingFocusFit: String {
  case fit
  case center
}
