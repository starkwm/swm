import CoreGraphics

/// Projects a virtual strip onto macOS's shared display coordinates.
struct ScrollingWindowPlacement {
  /// Leave a one-point sliver on the owner so macOS can retain display ownership.
  private static let sliver: CGFloat = 1

  func place(
    _ frames: [CGWindowID: CGRect],
    on display: SpaceTopologyDisplay,
    otherDisplays: [SpaceTopologyDisplay]
  ) -> ScrollingPlacementResult {
    let bounds = display.frame ?? display.visibleFrame
    let neighbors = otherDisplays.map { $0.frame ?? $0.visibleFrame }
    var physicalFrames = [CGWindowID: CGRect]()
    var parked = Set<CGWindowID>()

    for (windowID, frame) in frames {
      let intersection = frame.intersection(display.visibleFrame)
      if !intersection.isNull, intersection.width > Self.sliver,
        !neighbors.contains(where: { overlaps(frame, $0) })
      {
        physicalFrames[windowID] = frame
        continue
      }

      guard let target = parkingFrame(for: frame, in: bounds, neighbors: neighbors) else {
        return .insufficientSpace(.scrollingParking)
      }
      physicalFrames[windowID] = target
      parked.insert(windowID)
    }

    return .frames(physicalFrames, parkedWindowIDs: parked)
  }

  private func parkingFrame(for frame: CGRect, in bounds: CGRect, neighbors: [CGRect]) -> CGRect? {
    let x = min(max(frame.minX, bounds.minX), max(bounds.minX, bounds.maxX - frame.width))
    let y = min(max(frame.minY, bounds.minY), max(bounds.minY, bounds.maxY - frame.height))
    let left = CGRect(
      x: bounds.minX - frame.width + Self.sliver,
      y: y,
      width: frame.width,
      height: frame.height
    )
    let right = CGRect(
      x: bounds.maxX - Self.sliver,
      y: y,
      width: frame.width,
      height: frame.height
    )
    let top = CGRect(
      x: x,
      y: bounds.minY - frame.height + Self.sliver,
      width: frame.width,
      height: frame.height
    )
    let bottom = CGRect(
      x: x,
      y: bounds.maxY - Self.sliver,
      width: frame.width,
      height: frame.height
    )
    let horizontal = frame.midX < bounds.midX ? [left, right] : [right, left]

    return (horizontal + [bottom, top]).first { candidate in
      !neighbors.contains { overlaps(candidate, $0) }
    }
  }

  private func overlaps(_ first: CGRect, _ second: CGRect) -> Bool {
    let intersection = first.intersection(second)
    return !intersection.isNull && intersection.width > 0 && intersection.height > 0
  }
}

enum ScrollingPlacementResult {
  case frames([CGWindowID: CGRect], parkedWindowIDs: Set<CGWindowID>)
  case insufficientSpace(TilingLayoutConstraint)
}
