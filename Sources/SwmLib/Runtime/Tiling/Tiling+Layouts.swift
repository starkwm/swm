import CoreGraphics

extension Tiling {
  @discardableResult
  func setLayout(_ selection: LayoutSelection, for spaceID: UInt64) -> Bool {
    let updated = updateLayouts(for: spaceID, reflowing: nil) { state in
      frameReconciler?.cancelAnimations(for: state.tree?.windowIDs ?? [])
      state.selection = selection
    }
    guard updated else { return false }

    applyLayoutSelection(selection) { reflow(spaceID: spaceID) }
    return true
  }

  func setLayoutForSpaces(_ selection: LayoutSelection) {
    frameReconciler?.cancelAnimations()
    updateAllLayouts(reflowing: nil) { $0.selection = selection }
    applyLayoutSelection(selection) { reflowVisibleSpaces() }
  }

  @discardableResult
  func changeMasterRatio(_ change: LayoutRatioChange, for spaceID: UInt64) -> Bool {
    guard let state = layoutState(for: spaceID) else { return false }
    let ratio = change.applying(to: state.masterRatio)
    return updateLayouts(for: spaceID, reflowing: .master) { $0.masterRatio = ratio }
  }

  func changeMasterRatioForAllSpaces(_ change: LayoutRatioChange) {
    let ratio = change.applying(to: defaultState.masterRatio)
    updateAllLayouts(reflowing: .master) { $0.masterRatio = ratio }
  }

  @discardableResult
  func setMasterPlacement(_ placement: MasterPlacement, for spaceID: UInt64) -> Bool {
    updateLayouts(for: spaceID, reflowing: .master) { $0.masterPlacement = placement }
  }

  @discardableResult
  func cycleMasterPlacement(
    _ direction: CycleDirection,
    for spaceID: UInt64
  ) -> MasterPlacement? {
    guard let state = layoutState(for: spaceID) else { return nil }
    let placement = state.masterPlacement.cycled(in: direction)
    updateLayouts(for: spaceID, reflowing: .master) { $0.masterPlacement = placement }
    return placement
  }

  func setMasterPlacementForAllSpaces(_ placement: MasterPlacement) {
    updateAllLayouts(reflowing: .master) { $0.masterPlacement = placement }
  }

  @discardableResult
  func changeSplitRatio(_ change: LayoutRatioChange, for spaceID: UInt64) -> Bool {
    guard let state = layoutState(for: spaceID) else { return false }
    let ratio = change.applying(to: state.splitRatio)
    return updateLayouts(for: spaceID, reflowing: .dwindle) { $0.setSplitRatio(ratio) }
  }

  func changeSplitRatioForAllSpaces(_ change: LayoutRatioChange) {
    let ratio = change.applying(to: defaultState.splitRatio)
    updateAllLayouts(reflowing: .dwindle) { $0.setSplitRatio(ratio) }
  }

  @discardableResult
  func setSplitDirectionPreservation(_ enabled: Bool, for spaceID: UInt64) -> Bool {
    updateLayouts(for: spaceID, reflowing: .dwindle) {
      $0.setPreserveSplitDirections(enabled)
    }
  }

  func setSplitDirectionPreservationForAllSpaces(_ enabled: Bool) {
    updateAllLayouts(reflowing: .dwindle) { $0.setPreserveSplitDirections(enabled) }
  }

  func reflow(spaceID: UInt64) {
    applyPlans(for: layoutIDs(for: spaceID))
  }

  func reflowVisibleSpaces() {
    guard let currentTopology else { return }
    applyPlans(for: currentTopology.visibleLayoutIDs.sorted())
  }

  func layoutPlan(for layoutID: TilingLayoutID) -> [CGWindowID: CGRect]? {
    guard var state = layoutsByID[layoutID], state.selection != .float else { return nil }
    guard let topology = currentTopology, topology.visibleLayoutIDs.contains(layoutID) else {
      return nil
    }
    guard let display = topology.displaysByID[layoutID.displayID] else { return nil }

    let spaceSettings = spaces.settings(for: layoutID.spaceID)
    if state.selection == .dwindle, state.preserveSplitDirections {
      state.tree = dwindleLayout.resolvingSplitDirections(
        in: state.tree,
        bounds: display.visibleFrame,
        settings: spaceSettings,
        hiding: hiddenWindowIDs(in: state),
        minimumSizes: minimumSizeByWindowID
      )
      layoutsByID[layoutID] = state
    }
    let activeTree = activeTree(of: state)

    switch state.selection {
    case .float:
      return nil
    case .master:
      return masterLayout.layout(
        windowIDs: activeTree?.windowIDs ?? [],
        in: display.visibleFrame,
        settings: spaceSettings,
        masterRatio: state.masterRatio,
        placement: state.masterPlacement,
        minimumSizes: minimumSizeByWindowID
      )
    case .monocle:
      return monocleLayout.layout(
        windowIDs: activeTree?.windowIDs ?? [],
        in: display.visibleFrame,
        settings: spaceSettings
      )
    case .dwindle:
      return dwindleLayout.layout(
        tree: activeTree,
        in: display.visibleFrame,
        settings: spaceSettings,
        minimumSizes: minimumSizeByWindowID
      )
    }
  }

  func applyPlans(for layoutIDs: some Sequence<TilingLayoutID>) {
    for layoutID in layoutIDs {
      guard let frames = layoutPlan(for: layoutID) else {
        if let context = dwindleContext(layoutID), dwindleAttempts[layoutID]?.context != context {
          frameReconciler?.cancelAnimations(for: context.tree?.windowIDs ?? [])
          dwindleAttempts[layoutID] = DwindleAttempt(context: context)
          logUnsatisfiedDwindle(layoutID)
        }
        continue
      }
      if layoutsByID[layoutID]?.selection == .dwindle {
        applyDwindle(layoutID, frames: frames)
      } else {
        frameReconciler?.apply(frames)
      }
    }
  }

  func dwindleContext(_ id: TilingLayoutID) -> DwindleContext? {
    guard let state = layoutsByID[id], state.selection == .dwindle,
      let topology = currentTopology, topology.visibleLayoutIDs.contains(id),
      let display = topology.displaysByID[id.displayID]
    else { return nil }
    let tree = activeTree(of: state)
    let windowIDs = Set(tree?.windowIDs ?? [])
    return DwindleContext(
      tree: tree,
      bounds: display.visibleFrame,
      settings: spaces.settings(for: id.spaceID),
      minimumSizes: minimumSizeByWindowID.filter { windowIDs.contains($0.key) }
    )
  }

  /// Remembers the size a window kept when it refused to shrink to its tile, so later
  /// layouts make room for it.
  func recordRefusedFrame(for windowID: CGWindowID, target: CGRect, actual: CGRect) {
    let tolerance: CGFloat = 1
    let previous = minimumSizeByWindowID[windowID] ?? .zero
    var minimum = previous
    if actual.width > target.width + tolerance {
      minimum.width = max(minimum.width, actual.width)
    }
    if actual.height > target.height + tolerance {
      minimum.height = max(minimum.height, actual.height)
    }
    guard minimum != previous else { return }

    minimumSizeByWindowID[windowID] = minimum
    log("window minimum size id: \(windowID) \(minimum.width)x\(minimum.height)")
    // Refit once the whole dwindle batch reports, so every refusal in it shapes one layout.
    if let id = layoutIDByWindowID[windowID], let attempt = dwindleAttempts[id], attempt.isPending,
      attempt.context.tree?.windowIDs.contains(windowID) == true
    {
      attempt.needsRefit = true
      return
    }
    scheduleReconcileAndReflow()
  }

  func retryDwindle(_ ids: some Sequence<TilingLayoutID>) {
    for id in ids {
      dwindleAttempts.removeValue(forKey: id)
      frameReconciler?.cancelAnimations(for: layoutsByID[id]?.tree?.windowIDs ?? [])
    }
  }

  private func applyDwindle(_ id: TilingLayoutID, frames: [CGWindowID: CGRect]) {
    guard let context = dwindleContext(id), !frames.isEmpty else { return }
    if dwindleAttempts[id]?.context == context { return }
    let attempt = DwindleAttempt(context: context)
    dwindleAttempts[id] = attempt

    frameReconciler?.apply(frames) { [weak self] results in
      guard let self, self.dwindleAttempts[id] === attempt else { return }
      attempt.isPending = false
      if attempt.needsRefit {
        self.scheduleReconcileAndReflow()
        return
      }
      guard self.dwindleContext(id) == attempt.context else { return }
      attempt.verified = results.values.allSatisfy { $0 }
      if !attempt.verified { self.logUnsatisfiedDwindle(id) }
    }
  }

  private func logUnsatisfiedDwindle(_ id: TilingLayoutID) {
    log("dwindle layout unsatisfied space=\(id.spaceID)", level: .warn)
  }

  @discardableResult
  private func updateLayouts(
    for spaceID: UInt64,
    reflowing selection: LayoutSelection?,
    _ update: (inout TilingLayoutState) -> Void
  ) -> Bool {
    let layoutIDs = layoutIDs(for: spaceID)
    guard !layoutIDs.isEmpty else { return false }

    retryDwindle(layoutIDs)
    for layoutID in layoutIDs {
      guard var state = layoutsByID[layoutID] else { continue }
      update(&state)
      layoutsByID[layoutID] = state
    }
    if let selection {
      applyPlans(for: layoutIDs, matching: selection)
    }
    return true
  }

  private func updateAllLayouts(
    reflowing selection: LayoutSelection?,
    _ update: (inout TilingLayoutState) -> Void
  ) {
    retryDwindle(Array(layoutsByID.keys))
    update(&defaultState)
    layoutsByID = layoutsByID.mapValues { currentState in
      var state = currentState
      update(&state)
      return state
    }
    if let selection {
      reflowVisibleLayouts(matching: selection)
    }
  }

  private func applyLayoutSelection(_ selection: LayoutSelection, reflow: () -> Void) {
    updateMembershipPolling()
    if selection == .float {
      reconcile()
    } else {
      reflow()
    }
  }

  private func reflowVisibleLayouts(matching selection: LayoutSelection) {
    guard let currentTopology else { return }
    applyPlans(for: currentTopology.visibleLayoutIDs.sorted(), matching: selection)
  }

  private func applyPlans(
    for layoutIDs: some Sequence<TilingLayoutID>,
    matching selection: LayoutSelection
  ) {
    applyPlans(for: layoutIDs.filter { layoutsByID[$0]?.selection == selection })
  }
}

struct DwindleContext: Equatable {
  let tree: TilingTree?
  let bounds: CGRect
  let settings: SpaceSettings
  let minimumSizes: [CGWindowID: CGSize]
}

final class DwindleAttempt {
  let context: DwindleContext
  var verified = false
  var isPending = true
  var needsRefit = false

  init(context: DwindleContext) { self.context = context }
}
