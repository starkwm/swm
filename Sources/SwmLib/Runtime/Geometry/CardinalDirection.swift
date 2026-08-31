import CoreGraphics

/// Cardinal direction used to select a neighbouring window by frame geometry.
enum CardinalDirection: String, Equatable {
  case left
  case right
  case up
  case down

  private var vector: CGVector {
    switch self {
    case .left:
      CGVector(dx: -1, dy: 0)
    case .right:
      CGVector(dx: 1, dy: 0)
    case .up:
      CGVector(dx: 0, dy: -1)
    case .down:
      CGVector(dx: 0, dy: 1)
    }
  }

  /// Return the closest directionally aligned window from a set of frames.
  func neighbor(
    of windowID: CGWindowID,
    in framesByWindowID: [CGWindowID: CGRect]
  ) -> CGWindowID? {
    guard let sourceFrame = framesByWindowID[windowID] else { return nil }
    let vector = vector

    return
      framesByWindowID
      .compactMap { candidateWindowID, candidateFrame -> DirectionalWindowCandidate? in
        guard candidateWindowID != windowID else { return nil }
        let offset = CGVector(
          dx: candidateFrame.midX - sourceFrame.midX,
          dy: candidateFrame.midY - sourceFrame.midY
        )
        let primaryDistance = offset.dx * vector.dx + offset.dy * vector.dy
        guard primaryDistance > 0 else { return nil }

        let perpendicularDistance = abs(offset.dx * vector.dy - offset.dy * vector.dx)
        let perpendicularOverlap =
          vector.dx == 0
          ? overlap(sourceFrame.minX...sourceFrame.maxX, candidateFrame.minX...candidateFrame.maxX)
          : overlap(sourceFrame.minY...sourceFrame.maxY, candidateFrame.minY...candidateFrame.maxY)
        return DirectionalWindowCandidate(
          windowID: candidateWindowID,
          isAligned: perpendicularOverlap > 0,
          primaryDistance: primaryDistance,
          perpendicularDistance: perpendicularDistance
        )
      }
      .min { first, second in
        if first.isAligned != second.isAligned {
          return first.isAligned
        }
        if first.primaryDistance != second.primaryDistance {
          return first.primaryDistance < second.primaryDistance
        }
        if first.perpendicularDistance != second.perpendicularDistance {
          return first.perpendicularDistance < second.perpendicularDistance
        }
        return first.windowID < second.windowID
      }?
      .windowID
  }

  /// Return the positive overlap between two one-dimensional ranges.
  private func overlap(_ first: ClosedRange<CGFloat>, _ second: ClosedRange<CGFloat>) -> CGFloat {
    max(0, min(first.upperBound, second.upperBound) - max(first.lowerBound, second.lowerBound))
  }
}

/// Ranking facts for one window in a requested direction.
private struct DirectionalWindowCandidate {
  let windowID: CGWindowID
  let isAligned: Bool
  let primaryDistance: CGFloat
  let perpendicularDistance: CGFloat
}
