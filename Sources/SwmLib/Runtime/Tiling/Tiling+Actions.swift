import CoreGraphics

extension Tiling {
  @discardableResult
  func swapWindow(_ windowID: CGWindowID, in direction: CardinalDirection) -> Bool {
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }
    guard let state = layoutsByID[layoutID] else { return false }
    if state.selection == .float || floatingOverrideWindowIDs.contains(windowID) {
      return swapFloatingWindow(windowID, in: direction, layoutID: layoutID, state: state)
    }
    guard let framesByWindowID = layoutPlan(for: layoutID) else { return false }
    guard let neighborWindowID = direction.neighbor(of: windowID, in: framesByWindowID) else {
      return false
    }
    return mutateTree(containing: windowID, focus: true) {
      $0.swap(windowID, with: neighborWindowID)
    }
  }

  @discardableResult
  func swapWindowWithMaster(_ windowID: CGWindowID) -> Bool {
    guard let masterWindowID = masterWindowID(inLayoutContaining: windowID) else { return false }
    return mutateTree(containing: windowID, requiring: .master, focus: true) {
      $0.swap(windowID, with: masterWindowID)
    }
  }

  func masterWindowID(inLayoutContaining windowID: CGWindowID) -> CGWindowID? {
    guard let layoutID = layoutIDByWindowID[windowID] else { return nil }
    guard let state = layoutsByID[layoutID], state.selection == .master else { return nil }
    return activeTree(of: state)?.windowIDs.first
  }

  @discardableResult
  func setWindowLayout(_ selection: WindowLayoutSelection, for windowID: CGWindowID) -> Bool {
    guard let topology = currentTopology else { return false }
    guard topology.normalSpaceIDs(for: windowID).count == 1 else { return false }
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }

    cancelAnimation(for: windowID)
    let shouldFloat: Bool
    switch selection {
    case .float: shouldFloat = true
    case .tile: shouldFloat = false
    case .toggle: shouldFloat = !floatingOverrideWindowIDs.contains(windowID)
    }
    manualFloatingByWindowID[windowID] = shouldFloat
    if shouldFloat, layoutsByID[layoutID]?.focusedWindowID == windowID {
      layoutsByID[layoutID]?.focusedWindowID = nil
    }
    reconcile()
    let refreshedLayoutID = layoutIDByWindowID[windowID]
    applyPlans(for: Set([layoutID, refreshedLayoutID].compactMap { $0 }).sorted())
    return true
  }

  func cycledWindowID(
    from windowID: CGWindowID?,
    in direction: CycleDirection,
    fallbackSpaceID: UInt64? = nil
  ) -> CGWindowID? {
    let sourceLayoutID = windowID.flatMap { windowID in
      layoutIDByWindowID[windowID]
        ?? fixedSizeLayoutIDByWindowID[windowID].flatMap {
          layoutsByID[$0]?.selection == .float ? $0 : nil
        }
    }
    guard
      let layoutID = sourceLayoutID
        ?? fallbackSpaceID.flatMap({ spaceID in
          layoutIDs(for: spaceID).first {
            currentTopology?.visibleLayoutIDs.contains($0) == true
          }
        })
    else { return nil }
    guard let state = layoutsByID[layoutID] else { return nil }
    var windowIDs = availableWindowIDs(in: state, floating: false)
    if state.selection == .float {
      windowIDs += fixedSizeLayoutIDByWindowID.keys.filter {
        fixedSizeLayoutIDByWindowID[$0] == layoutID
      }.sorted()
    }
    guard let windowID, sourceLayoutID != nil else {
      return direction == .next ? windowIDs.first : windowIDs.last
    }
    guard windowIDs.count > 1, let index = windowIDs.firstIndex(of: windowID) else { return nil }

    switch direction {
    case .next:
      return windowIDs[(index + 1) % windowIDs.count]
    case .prev:
      return windowIDs[(index - 1 + windowIDs.count) % windowIDs.count]
    }
  }

  @discardableResult
  func swapWindowInOrder(_ windowID: CGWindowID, in direction: CycleDirection) -> Bool {
    guard let neighborWindowID = cycledWindowID(from: windowID, in: direction) else {
      return false
    }
    return mutateTree(containing: windowID, focus: true) {
      $0.swap(windowID, with: neighborWindowID)
    }
  }

  @discardableResult
  func changeDwindleSplitRatio(
    _ change: LayoutRatioChange,
    for windowID: CGWindowID
  ) -> CGFloat? {
    var ratio: CGFloat?
    let hiddenWindowIDs = hiddenWindowIDs(inLayoutContaining: windowID)
    _ = mutateTree(containing: windowID, requiring: .dwindle) {
      ratio = $0.changeSplitRatio(change, containing: windowID, hiding: hiddenWindowIDs)
      return ratio != nil
    }
    return ratio
  }

  @discardableResult
  func toggleDwindleSplit(for windowID: CGWindowID) -> Bool {
    guard !floatingOverrideWindowIDs.contains(windowID) else { return false }
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }
    guard let state = layoutsByID[layoutID], state.preserveSplitDirections else { return false }
    guard let context = dwindleContext(layoutID) else { return false }
    let hiddenWindowIDs = hiddenWindowIDs(in: state)
    return mutateTree(containing: windowID, requiring: .dwindle) { tree in
      tree =
        dwindleLayout.resolvingSplitDirections(
          in: tree,
          bounds: context.bounds,
          settings: context.settings,
          hiding: hiddenWindowIDs
        ) ?? tree
      return tree.toggleSplitDirection(containing: windowID, hiding: hiddenWindowIDs)
    }
  }

  @discardableResult
  func swapDwindleSplit(for windowID: CGWindowID) -> Bool {
    let hiddenWindowIDs = hiddenWindowIDs(inLayoutContaining: windowID)
    return mutateTree(containing: windowID, requiring: .dwindle) {
      $0.swapSplit(containing: windowID, hiding: hiddenWindowIDs)
    }
  }

  private func mutateTree(
    containing windowID: CGWindowID,
    requiring selection: LayoutSelection? = nil,
    focus: Bool = false,
    _ mutation: (inout TilingTree) -> Bool
  ) -> Bool {
    guard !floatingOverrideWindowIDs.contains(windowID) else { return false }
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }
    guard var state = layoutsByID[layoutID], state.selection != .float else { return false }
    if let selection, state.selection != selection { return false }
    guard var tree = state.tree, mutation(&tree) else { return false }

    retryDwindle([layoutID])
    state.tree = tree
    if focus { state.focusedWindowID = windowID }
    layoutsByID[layoutID] = state
    applyPlans(for: [layoutID])
    return true
  }

  private func swapFloatingWindow(
    _ windowID: CGWindowID,
    in direction: CardinalDirection,
    layoutID: TilingLayoutID,
    state: TilingLayoutState
  ) -> Bool {
    guard currentTopology?.visibleLayoutIDs.contains(layoutID) == true else { return false }
    guard let frameReconciler else { return false }

    let framesByWindowID = frameReconciler.frames(
      for: availableWindowIDs(in: state, floating: true)
    )
    guard
      let sourceFrame = framesByWindowID[windowID],
      let neighborWindowID = direction.neighbor(of: windowID, in: framesByWindowID),
      let neighborFrame = framesByWindowID[neighborWindowID]
    else {
      return false
    }

    frameReconciler.apply([
      windowID: neighborFrame,
      neighborWindowID: sourceFrame,
    ])
    return true
  }
}
