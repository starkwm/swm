import CoreGraphics

struct DwindleLayout {
  func layout(
    tree: TilingTree?,
    in bounds: CGRect,
    settings: SpaceSettings,
    minimumSizes: [CGWindowID: CGSize] = [:]
  ) -> [CGWindowID: CGRect]? {
    guard let tree else { return [:] }
    guard let usableBounds = settings.usableTilingBounds(in: bounds) else { return nil }

    let splitter = Splitter(gap: settings.tilingGap, minimumSizes: minimumSizes)
    var framesByWindowID = [CGWindowID: CGRect]()
    guard layout(tree, in: usableBounds, splitter: splitter, framesByWindowID: &framesByWindowID)
    else { return nil }
    return framesByWindowID
  }

  func resolvingSplitDirections(
    in tree: TilingTree?,
    bounds: CGRect,
    settings: SpaceSettings,
    hiding hiddenWindowIDs: Set<CGWindowID> = [],
    minimumSizes: [CGWindowID: CGSize] = [:]
  ) -> TilingTree? {
    guard let tree else { return nil }
    return resolvingSplitDirections(
      in: tree,
      bounds: settings.tilingBounds(in: bounds),
      splitter: Splitter(gap: settings.tilingGap, minimumSizes: minimumSizes),
      hiding: hiddenWindowIDs
    )
  }

  private func layout(
    _ tree: TilingTree,
    in bounds: CGRect,
    splitter: Splitter,
    framesByWindowID: inout [CGWindowID: CGRect]
  ) -> Bool {
    switch tree {
    case .leaf(let windowID):
      guard bounds.size.meetsTilingMinimum else { return false }
      framesByWindowID[windowID] = bounds
      return true
    case .branch(let first, let second, let split):
      guard let (firstBounds, secondBounds) = splitter.split(bounds, first, second, split) else {
        return false
      }
      return layout(first, in: firstBounds, splitter: splitter, framesByWindowID: &framesByWindowID)
        && layout(second, in: secondBounds, splitter: splitter, framesByWindowID: &framesByWindowID)
    }
  }

  private func resolvingSplitDirections(
    in tree: TilingTree,
    bounds: CGRect,
    splitter: Splitter,
    hiding hiddenWindowIDs: Set<CGWindowID>
  ) -> TilingTree {
    switch tree {
    case .leaf:
      return tree
    case .branch(let first, let second, var split):
      let firstIsVisible = first.removing(hiddenWindowIDs) != nil
      let secondIsVisible = second.removing(hiddenWindowIDs) != nil
      guard firstIsVisible, secondIsVisible else {
        let resolve = {
          resolvingSplitDirections(
            in: $0,
            bounds: bounds,
            splitter: splitter,
            hiding: hiddenWindowIDs
          )
        }
        return .branch(
          firstIsVisible ? resolve(first) : first,
          secondIsVisible ? resolve(second) : second,
          split: split
        )
      }
      split.direction = split.direction ?? TilingSplitDirection(longestEdgeOf: bounds)
      guard let (firstBounds, secondBounds) = splitter.split(bounds, first, second, split) else {
        return .branch(first, second, split: split)
      }
      return .branch(
        resolvingSplitDirections(
          in: first,
          bounds: firstBounds,
          splitter: splitter,
          hiding: hiddenWindowIDs
        ),
        resolvingSplitDirections(
          in: second,
          bounds: secondBounds,
          splitter: splitter,
          hiding: hiddenWindowIDs
        ),
        split: split
      )
    }
  }
}

extension TilingSplitDirection {
  fileprivate init(longestEdgeOf bounds: CGRect) {
    self = bounds.width >= bounds.height ? .vertical : .horizontal
  }
}

/// Divides a region between the two sides of a split. When window minimum sizes are
/// known, the split moves so each side fits the windows it holds.
private struct Splitter {
  let gap: CGFloat

  let minimumSizes: [CGWindowID: CGSize]

  func split(
    _ bounds: CGRect,
    _ first: TilingTree,
    _ second: TilingTree,
    _ split: TilingSplit
  ) -> (CGRect, CGRect)? {
    let vertical = isVertical(split, in: bounds)
    let available = length(of: bounds.size, vertical: vertical) - gap
    var allocation = preferredAllocation(for: split, of: available)
    if !minimumSizes.isEmpty {
      let (firstBounds, secondBounds) = divided(bounds, vertical: vertical, at: allocation)
      allocation = TilingLimits.allocation(
        allocation,
        of: available,
        firstMinimum: length(of: minimumSize(of: first, in: firstBounds), vertical: vertical),
        secondMinimum: length(of: minimumSize(of: second, in: secondBounds), vertical: vertical)
      )
    }
    let minimum = TilingLimits.minimumWindowLength
    guard allocation >= minimum, available - allocation >= minimum else { return nil }
    return divided(bounds, vertical: vertical, at: allocation)
  }

  /// The smallest size that fits the known minimum of every window in a subtree.
  private func minimumSize(of tree: TilingTree, in bounds: CGRect) -> CGSize {
    switch tree {
    case .leaf(let windowID):
      return minimumSizes[windowID] ?? .zero
    case .branch(let first, let second, let split):
      let vertical = isVertical(split, in: bounds)
      let available = length(of: bounds.size, vertical: vertical) - gap
      let allocation = preferredAllocation(for: split, of: available)
      let (firstBounds, secondBounds) = divided(bounds, vertical: vertical, at: allocation)
      let firstSize = minimumSize(of: first, in: firstBounds)
      let secondSize = minimumSize(of: second, in: secondBounds)
      return vertical
        ? CGSize(
          width: firstSize.width + gap + secondSize.width,
          height: max(firstSize.height, secondSize.height)
        )
        : CGSize(
          width: max(firstSize.width, secondSize.width),
          height: firstSize.height + gap + secondSize.height
        )
    }
  }

  private func isVertical(_ split: TilingSplit, in bounds: CGRect) -> Bool {
    (split.direction ?? TilingSplitDirection(longestEdgeOf: bounds)) == .vertical
  }

  private func preferredAllocation(for split: TilingSplit, of available: CGFloat) -> CGFloat {
    (available * TilingLimits.clampedRatio(split.ratio)).rounded()
  }

  private func length(of size: CGSize, vertical: Bool) -> CGFloat {
    vertical ? size.width : size.height
  }

  private func divided(
    _ bounds: CGRect,
    vertical: Bool,
    at allocation: CGFloat
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
