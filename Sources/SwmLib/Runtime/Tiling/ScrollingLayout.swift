import CoreGraphics

/// Pure strip geometry; physical off-screen placement is calculated separately.
struct ScrollingLayout {
  func layout(
    state: ScrollingLayoutState,
    omittedWindowIDs: Set<CGWindowID>,
    focusedWindowID: CGWindowID?,
    in bounds: CGRect,
    settings: SpaceSettings,
    minimumWidths: [CGWindowID: CGFloat] = [:]
  ) -> ScrollingLayoutResult {
    let columns = state.columns.filter { !omittedWindowIDs.contains($0.windowID) }
    guard !columns.isEmpty else {
      var empty = state
      empty.viewportOffset = 0
      empty.anchorWindowID = nil
      return .plan(ScrollingLayoutPlan(state: empty, frames: [:]))
    }

    let usable = settings.tilingBounds(in: bounds)
    guard usable.width >= 1, usable.height >= 1 else {
      return .insufficientSpace(.usableBounds)
    }

    let gap = settings.tilingGap
    var logicalFrames = [CGWindowID: CGRect]()
    var x: CGFloat = 0
    for column in columns {
      // Two half-width columns fit exactly, including the gap between them.
      let width = max(
        column.width * (usable.width + gap) - gap,
        minimumWidths[column.windowID] ?? 0
      )
      guard width >= 1, width <= usable.width else {
        return .insufficientSpace(.scrollingColumnWidth)
      }
      logicalFrames[column.windowID] = CGRect(x: x, y: 0, width: width, height: usable.height)
      x += width + gap
    }

    let contentWidth = x - gap
    var offset = state.viewportOffset
    if let anchor = state.anchorWindowID, let frame = logicalFrames[anchor] {
      offset = frame.minX - state.anchorPosition
    }
    if let focusedWindowID, let frame = logicalFrames[focusedWindowID] {
      switch state.reveal ?? .fit {
      case .fit:
        if frame.minX < offset { offset = frame.minX }
        if frame.maxX > offset + usable.width { offset = frame.maxX - usable.width }
      case .center:
        offset = frame.midX - usable.width / 2
      }
    }

    // Retain intentional centering at either end of the strip.
    let first = logicalFrames[columns[0].windowID]!
    let last = logicalFrames[columns[columns.count - 1].windowID]!
    let minimumOffset = min(0, first.midX - usable.width / 2)
    let maximumOffset = max(0, max(contentWidth - usable.width, last.midX - usable.width / 2))
    offset = min(maximumOffset, max(minimumOffset, offset))

    var updated = state
    updated.viewportOffset = offset
    updated.reveal = nil
    updated.anchorWindowID =
      focusedWindowID.flatMap { logicalFrames[$0] == nil ? nil : $0 }
      ?? state.anchorWindowID.flatMap { logicalFrames[$0] == nil ? nil : $0 }
      ?? columns.first?.windowID
    if let anchor = updated.anchorWindowID, let frame = logicalFrames[anchor] {
      updated.anchorPosition = frame.minX - offset
    }

    return .plan(
      ScrollingLayoutPlan(
        state: updated,
        frames: logicalFrames.mapValues {
          $0.offsetBy(dx: usable.minX - offset, dy: usable.minY)
        }
      )
    )
  }
}

enum ScrollingLayoutResult {
  case plan(ScrollingLayoutPlan)
  case insufficientSpace(TilingLayoutConstraint)
}

struct ScrollingLayoutPlan {
  let state: ScrollingLayoutState
  let frames: [CGWindowID: CGRect]
}
