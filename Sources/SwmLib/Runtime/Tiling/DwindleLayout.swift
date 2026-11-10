import CoreGraphics

/// Pure ordered geometry calculator that recursively bisects the remaining bounds.
struct DwindleLayout {
  /// Calculate frames for persistent dwindle sibling relationships, or nil when they do not fit.
  func layout(
    tree: TilingTree?,
    in bounds: CGRect,
    settings: SpaceSettings
  ) -> [CGWindowID: CGRect]? {
    guard let tree else { return [:] }
    guard let usableBounds = settings.usableTilingBounds(in: bounds) else { return nil }

    var framesByWindowID = [CGWindowID: CGRect]()
    guard
      layout(tree, in: usableBounds, gap: settings.tilingGap, framesByWindowID: &framesByWindowID)
    else { return nil }
    return framesByWindowID
  }

  /// Resolve dynamic branch directions from their current bounds and retain them in a copy.
  ///
  /// Hidden windows receive no bounds, so a branch with a hidden side keeps its own direction and
  /// passes its whole region to the visible side, matching the geometry drawn without them.
  func resolvingSplitDirections(
    in tree: TilingTree?,
    bounds: CGRect,
    settings: SpaceSettings,
    hiding hiddenWindowIDs: Set<CGWindowID> = []
  ) -> TilingTree? {
    guard let tree else { return nil }
    return resolvingSplitDirections(
      in: tree,
      bounds: settings.tilingBounds(in: bounds),
      gap: settings.tilingGap,
      hiding: hiddenWindowIDs
    )
  }

  /// Recursively calculate leaf frames from the retained binary tree, returning whether they fit.
  private func layout(
    _ tree: TilingTree,
    in bounds: CGRect,
    gap: CGFloat,
    framesByWindowID: inout [CGWindowID: CGRect]
  ) -> Bool {
    switch tree {
    case .leaf(let windowID):
      guard bounds.size.meetsTilingMinimum else { return false }
      framesByWindowID[windowID] = bounds
      return true
    case .branch(let first, let second, let split):
      guard let (firstBounds, secondBounds) = splitBounds(bounds, gap: gap, split: split) else {
        return false
      }
      return layout(first, in: firstBounds, gap: gap, framesByWindowID: &framesByWindowID)
        && layout(second, in: secondBounds, gap: gap, framesByWindowID: &framesByWindowID)
    }
  }

  /// Resolve unset directions recursively while preserving existing branch ratios.
  private func resolvingSplitDirections(
    in tree: TilingTree,
    bounds: CGRect,
    gap: CGFloat,
    hiding hiddenWindowIDs: Set<CGWindowID>
  ) -> TilingTree {
    switch tree {
    case .leaf:
      return tree
    case .branch(let first, let second, var split):
      let firstIsVisible = first.removing(hiddenWindowIDs) != nil
      let secondIsVisible = second.removing(hiddenWindowIDs) != nil
      guard firstIsVisible, secondIsVisible else {
        // A branch with a hidden side draws as its visible side, which keeps the whole region.
        let resolve = {
          resolvingSplitDirections(in: $0, bounds: bounds, gap: gap, hiding: hiddenWindowIDs)
        }
        return .branch(
          firstIsVisible ? resolve(first) : first,
          secondIsVisible ? resolve(second) : second,
          split: split
        )
      }
      split.direction = split.direction ?? direction(for: bounds)
      guard let (firstBounds, secondBounds) = splitBounds(bounds, gap: gap, split: split) else {
        return .branch(first, second, split: split)
      }
      return .branch(
        resolvingSplitDirections(
          in: first,
          bounds: firstBounds,
          gap: gap,
          hiding: hiddenWindowIDs
        ),
        resolvingSplitDirections(
          in: second,
          bounds: secondBounds,
          gap: gap,
          hiding: hiddenWindowIDs
        ),
        split: split
      )
    }
  }

  /// Select a split direction from the longest edge of the current bounds.
  private func direction(for bounds: CGRect) -> TilingSplitDirection {
    bounds.width >= bounds.height ? .vertical : .horizontal
  }

  /// Divide bounds using retained geometry or the current longest edge, or return nil when the
  /// gap leaves either side below the minimum length.
  private func splitBounds(
    _ bounds: CGRect,
    gap: CGFloat,
    split: TilingSplit
  ) -> (CGRect, CGRect)? {
    let vertical = (split.direction ?? direction(for: bounds)) == .vertical
    let available = (vertical ? bounds.width : bounds.height) - gap
    let allocation = (available * TilingLimits.clampedRatio(split.ratio)).rounded()
    let minimum = TilingLimits.minimumWindowLength
    guard allocation >= minimum, available - allocation >= minimum else { return nil }
    return dividedBounds(bounds, gap: gap, vertical: vertical, allocation: allocation)
  }

  /// Construct sibling rectangles after the caller chooses a feasible allocation.
  private func dividedBounds(
    _ bounds: CGRect,
    gap: CGFloat,
    vertical: Bool,
    allocation: CGFloat
  ) -> (CGRect, CGRect) {
    var first = bounds
    var second = bounds
    if vertical {
      first.size.width = allocation
      second.origin.x += allocation + gap
      second.size.width = bounds.width - gap - allocation
    } else {
      first.size.height = allocation
      second.origin.y += allocation + gap
      second.size.height = bounds.height - gap - allocation
    }
    return (first, second)
  }
}
