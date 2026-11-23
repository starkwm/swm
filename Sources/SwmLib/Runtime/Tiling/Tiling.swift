import CoreGraphics

@MainActor
public final class Tiling {
  typealias RulePlacementHandler = (WindowRulePlacement, CGWindowID, TilingLayoutID) ->
    WindowRulePlacementResult
  typealias RuleSpaceMoveHandler = (CGWindowID, Int) async throws -> Void
  typealias SnapshotProvider = () -> TilingReconciliationSnapshot
  typealias WindowSpaceMembershipProvider = () -> [CGWindowID: Set<UInt64>]
  typealias UnavailableFactsProvider = (Set<CGWindowID>) -> Set<CGWindowID>
  typealias RuleIdentityProvider = (CGWindowID) -> WindowRuleIdentity?

  private static let maximumFactRetryInterval = 16

  private(set) var rules = [WindowRule]()

  private let masterLayout = MasterLayout()
  private let monocleLayout = MonocleLayout()
  private let dwindleLayout = DwindleLayout()
  private let snapshot: SnapshotProvider
  private let spaces: Spaces
  private let windows: Windows?
  private let frameReconciler: WindowFrameReconciler?
  private let windowSpaceMembership: WindowSpaceMembershipProvider
  private let unavailableFacts: UnavailableFactsProvider
  private let ruleIdentity: RuleIdentityProvider
  private let ruleDisplayIDs: () -> [String]
  private let rulePlacement: RulePlacementHandler
  private let ruleSpaceIDs: () -> [UInt64]
  private let ruleSpaceMove: RuleSpaceMoveHandler
  private var appliedRulePlacements = [CGWindowID: WindowRulePlacement]()
  private var ruleActionsByWindowID = [CGWindowID: WindowRuleActions]()
  private var scheduledReconcile: Task<Void, Never>?
  private var ruleSpaceMoveTasks = [CGWindowID: Task<Void, Never>]()
  private var currentTopology: SpaceTopology?
  private(set) var defaultState = TilingLayoutState(
    selection: .float,
    masterRatio: 0.5,
    masterPlacement: .left,
    splitRatio: 0.5,
    preserveSplitDirections: false,
    tree: nil,
    omittedWindowIDs: [],
    focusedWindowID: nil
  )
  private var manualFloatingByWindowID = [CGWindowID: Bool]()
  private var floatingOverrideWindowIDs = Set<CGWindowID>()
  private var layoutIDByWindowID = [CGWindowID: TilingLayoutID]()
  private var fixedSizeLayoutIDByWindowID = [CGWindowID: TilingLayoutID]()
  private var layoutsByID = [TilingLayoutID: TilingLayoutState]()
  private var dwindleAttempts = [TilingLayoutID: DwindleAttempt]()
  private var pendingFocusedWindowID: CGWindowID?
  private var membershipPollingTask: Task<Void, Never>?
  private var unavailableFactWindowIDs = Set<CGWindowID>()
  private var factRetryInterval = 1
  private var factRetryCountdown = 1

  public convenience init(windows: Windows, spaces: Spaces) {
    self.init(
      snapshot: {
        let windowSnapshots = windows.allWindows().map { $0.tilingSnapshot() }
        return TilingReconciliationSnapshot(
          windows: windowSnapshots,
          topology: spaces.snapshotTopology(for: windowSnapshots.map(\.id))
        )
      },
      spaces: spaces,
      windows: windows,
      frameReconciler: WindowFrameReconciler(
        currentFrame: { windows.window(by: $0)?.frame() },
        delivery: AnimationFrameDelivery(windows: windows)
      ),
      windowSpaceMembership: {
        Dictionary(
          uniqueKeysWithValues: windows.allWindows().map { window in
            (window.id, Set(WindowServerClient.shared.spaceIDs(containing: window.id)))
          }
        )
      },
      unavailableFacts: { windowIDs in
        windowIDs.filter { windows.window(by: $0)?.hasUnavailableTilingFacts ?? false }
      },
      ruleIdentity: { windowID in
        windows.window(by: windowID).map {
          WindowRuleIdentity(
            app: $0.application?.name,
            title: $0.title,
            bundleID: $0.application?.bundleID
          )
        }
      }
    )
  }

  init(
    snapshot: @escaping SnapshotProvider,
    spaces: Spaces,
    windows: Windows? = nil,
    frameReconciler: WindowFrameReconciler? = nil,
    windowSpaceMembership: WindowSpaceMembershipProvider? = nil,
    unavailableFacts: UnavailableFactsProvider? = nil,
    ruleIdentity: RuleIdentityProvider? = nil,
    rulePlacement: RulePlacementHandler? = nil,
    ruleDisplayIDs: @escaping () -> [String] = { WindowRulePlacementApplier.displayIDs() },
    ruleSpaceIDs: @escaping () -> [UInt64] = { WindowServerClient.shared.allSpaceIDs() },
    ruleSpaceMove: RuleSpaceMoveHandler? = nil
  ) {
    self.ruleDisplayIDs = ruleDisplayIDs
    self.ruleSpaceIDs = ruleSpaceIDs
    self.ruleSpaceMove =
      ruleSpaceMove ?? { windowID, index in
        guard let windows else { return }
        try await WindowRulePlacementApplier(windows: windows, spaces: spaces)
          .move(windowID, toSpace: index)
      }
    self.rulePlacement =
      rulePlacement ?? { placement, windowID, destination in
        guard let windows else { return .deferred }
        return WindowRulePlacementApplier(windows: windows, spaces: spaces)
          .apply(placement, to: windowID, destination: destination)
      }
    self.snapshot = snapshot
    self.spaces = spaces
    self.windows = windows
    self.frameReconciler = frameReconciler
    self.windowSpaceMembership =
      windowSpaceMembership ?? { snapshot().topology?.spaceIDsByWindowID ?? [:] }
    self.unavailableFacts =
      unavailableFacts ?? { windowIDs in
        Set(
          snapshot().windows.filter { windowIDs.contains($0.id) && $0.hasUnavailableFacts }
            .map(\.id)
        )
      }
    self.ruleIdentity =
      ruleIdentity ?? { windowID in
        snapshot().windows.first { $0.id == windowID }.map {
          WindowRuleIdentity(app: $0.app, title: $0.title, bundleID: $0.bundleID)
        }
      }
    if let windows {
      frameReconciler?.onInteractionEnded = { [weak self] in
        guard let self else { return }
        self.retryDwindle(Array(self.layoutsByID.keys))
        self.reconcileAndReflowVisibleSpaces()
      }
      frameReconciler?.monitorInteractions { point in
        guard let id = WindowServerClient.shared.frontmostWindowID(at: point),
          windows.window(by: id) != nil
        else { return nil }
        return id
      }
    }
  }

  deinit {
    membershipPollingTask?.cancel()
    scheduledReconcile?.cancel()
    for task in ruleSpaceMoveTasks.values { task.cancel() }
  }

  public func initialize() {
    reconcileAndReflowVisibleSpaces()
  }

  var animationDuration: Double { frameReconciler?.animationDuration ?? 0 }

  var animationEasing: AnimationEasing { frameReconciler?.animationEasing ?? .easeOutQuad }

  func setAnimationDuration(_ duration: Double) {
    frameReconciler?.animationDuration = duration
  }

  func setAnimationEasing(_ easing: AnimationEasing) {
    frameReconciler?.animationEasing = easing
  }

  func settingsSnapshot() -> TilingSettingsSnapshot {
    TilingSettingsSnapshot(
      animationDuration: animationDuration,
      animationEasing: animationEasing,
      defaults: defaultState.settings,
      byLayoutID: layoutsByID.mapValues(\.settings)
    )
  }

  @discardableResult
  func restoreSettings(_ snapshot: TilingSettingsSnapshot) -> Bool {
    setAnimationDuration(snapshot.animationDuration)
    setAnimationEasing(snapshot.animationEasing)
    defaultState.restore(snapshot.defaults)
    var changed = false
    for (layoutID, state) in layoutsByID {
      let settings = snapshot.byLayoutID[layoutID] ?? snapshot.defaults
      guard state.settings != settings else { continue }
      if state.selection != settings.selection {
        frameReconciler?.cancelAnimations(for: state.tree?.windowIDs ?? [])
      }
      layoutsByID[layoutID]?.restore(settings)
      changed = true
    }
    return changed
  }

  func destinationFrame(for windowID: CGWindowID) -> CGRect? {
    frameReconciler?.frames(for: [windowID])[windowID]
  }

  func animateFrame(_ frame: CGRect, for windowID: CGWindowID) -> Bool {
    guard let frameReconciler, frameReconciler.animationEnabled else { return false }
    frameReconciler.apply([windowID: frame])
    return true
  }

  func cancelAnimation(for windowID: CGWindowID) {
    frameReconciler?.cancelAnimations(for: [windowID])
  }

  func isInteractingWithWindow(_ windowID: CGWindowID) -> Bool {
    frameReconciler?.isInteracting(windowID) == true
  }

  func prepareForSynchronousMutation(for windowID: CGWindowID) {
    frameReconciler?.prepareForSynchronousMutation(for: windowID)
  }

  func cancelAnimations() {
    frameReconciler?.cancelAnimations()
    dwindleAttempts.removeAll()
  }

  func reconcile() {
    var snapshot = snapshot()
    guard snapshot.topology != nil else {
      suspendTopology()
      return
    }
    if let activeSpaceID = snapshot.topology?.activeSpaceID {
      spaces.restoreActiveSpace(activeSpaceID)
    }
    var windows = snapshot.windows.sorted { $0.id < $1.id }
    var liveIDs = Set(windows.map(\.id))
    let previousFloatingIDs = floatingOverrideWindowIDs
    manualFloatingByWindowID = manualFloatingByWindowID.filter { liveIDs.contains($0.key) }
    let actions = Dictionary(
      uniqueKeysWithValues: windows.map {
        ($0.id, WindowRuleActions.resolve(rules, for: $0))
      }
    )
    ruleActionsByWindowID = actions
    floatingOverrideWindowIDs = Set(
      windows.filter {
        manualFloatingByWindowID[$0.id] ?? (actions[$0.id]?.manage == false)
      }.map(\.id)
    )
    let placedWindowIDs = applyRulePlacements(actions, snapshot: snapshot)
    if !placedWindowIDs.isEmpty {
      snapshot = self.snapshot()
      windows = snapshot.windows.sorted { $0.id < $1.id }
      liveIDs = Set(windows.map(\.id))
    }
    guard let topology = snapshot.topology else {
      suspendTopology()
      return
    }
    for windowID in placedWindowIDs { layoutIDByWindowID.removeValue(forKey: windowID) }
    spaces.retainSettings(for: Set(topology.spacesByID.keys))
    let availableLayoutIDs = topology.layoutIDs
    let previousLayoutsByID = layoutsByID
    let resolvedSpaceIDs = Set(availableLayoutIDs.map(\.spaceID))
    let unresolvedSpaceIDs = Set(
      topology.spacesByID.values
        .filter { $0.type == .normal && !resolvedSpaceIDs.contains($0.id) }
        .map(\.id)
    )
    let retainedLayoutIDs = availableLayoutIDs.union(
      previousLayoutsByID.keys.filter { unresolvedSpaceIDs.contains($0.spaceID) }
    )

    layoutsByID = layoutsByID.filter { retainedLayoutIDs.contains($0.key) }
    for layoutID in availableLayoutIDs where layoutsByID[layoutID] == nil {
      layoutsByID[layoutID] = initialState(
        for: layoutID,
        previousLayoutsByID: previousLayoutsByID
      )
    }

    var retainedWindowIDsByLayoutID = [TilingLayoutID: Set<CGWindowID>]()
    var omittedWindowIDsByLayoutID = [TilingLayoutID: Set<CGWindowID>]()
    var newLayoutIDByWindowID = [CGWindowID: TilingLayoutID]()
    fixedSizeLayoutIDByWindowID.removeAll(keepingCapacity: true)

    for window in windows {
      if ruleSpaceMoveTasks[window.id] != nil {
        if let layoutID = layoutIDByWindowID[window.id], retainedLayoutIDs.contains(layoutID) {
          retainedWindowIDsByLayoutID[layoutID, default: []].insert(window.id)
          omittedWindowIDsByLayoutID[layoutID, default: []].insert(window.id)
          newLayoutIDByWindowID[window.id] = layoutID
        }
        continue
      }
      let disposition = WindowEligibilityPolicy.disposition(
        for: window,
        topology: topology,
        allowsDialogTiling: actions[window.id]?.manage == true
      )
      let placement: (layoutID: TilingLayoutID, isOmitted: Bool)

      switch disposition {
      case .excluded(.notResizable), .floating(.dialog):
        if !window.isMinimized,
          let layoutID = topology.layoutID(for: window.id, on: window.displayID)
        {
          fixedSizeLayoutIDByWindowID[window.id] = layoutID
        }
        continue

      case .tiled:
        if let layoutID = topology.layoutID(for: window.id, on: window.displayID) {
          placement = (layoutID, window.isMinimized)
        } else if let layoutID = layoutIDByWindowID[window.id],
          retainedLayoutIDs.contains(layoutID)
        {
          placement = (layoutID, true)
        } else {
          continue
        }

      case .excluded(.nativeFullscreen), .pending:
        guard
          let layoutID = layoutIDByWindowID[window.id],
          retainedLayoutIDs.contains(layoutID)
        else {
          continue
        }
        placement = (layoutID, true)

      case .floating, .excluded:
        continue
      }

      retainedWindowIDsByLayoutID[placement.layoutID, default: []].insert(window.id)
      if placement.isOmitted {
        omittedWindowIDsByLayoutID[placement.layoutID, default: []].insert(window.id)
      }
      newLayoutIDByWindowID[window.id] = placement.layoutID
    }

    for layoutID in retainedLayoutIDs {
      guard var state = layoutsByID[layoutID] else { continue }
      let desiredWindowIDs = retainedWindowIDsByLayoutID[layoutID] ?? []

      let retainedWindowIDs = Set(state.tree?.windowIDs ?? [])
      let removedWindowIDs = retainedWindowIDs.subtracting(desiredWindowIDs)
      if !removedWindowIDs.isEmpty {
        state.tree = state.tree?.removing(removedWindowIDs)
      }

      if let focusedWindowID = state.focusedWindowID,
        !desiredWindowIDs.contains(focusedWindowID)
          || floatingOverrideWindowIDs.contains(focusedWindowID)
      {
        state.focusedWindowID = nil
      }

      var insertionAnchor = state.focusedWindowID
      for windowID in desiredWindowIDs.sorted() where !retainedWindowIDs.contains(windowID) {
        if var tree = state.tree {
          tree.insert(windowID, beside: insertionAnchor, ratio: state.splitRatio)
          state.tree = tree
        } else {
          state.tree = .leaf(windowID)
        }
        insertionAnchor = windowID
      }

      state.omittedWindowIDs = omittedWindowIDsByLayoutID[layoutID] ?? []
      layoutsByID[layoutID] = state
    }

    if let previous = currentTopology,
      previous.displaysByID != topology.displaysByID
        || previous.visibleSpaceIDByDisplayID != topology.visibleSpaceIDByDisplayID
        || previous.spacesByID != topology.spacesByID
    {
      frameReconciler?.cancelAnimations()
    } else {
      let changedIDs = Set(layoutIDByWindowID.keys).union(newLayoutIDByWindowID.keys)
        .union(liveIDs).union(currentTopology?.spaceIDsByWindowID.keys.map { $0 } ?? [])
        .filter {
          layoutIDByWindowID[$0] != newLayoutIDByWindowID[$0]
            || currentTopology?.spaceIDsByWindowID[$0] != topology.spaceIDsByWindowID[$0]
            || !liveIDs.contains($0)
            || previousFloatingIDs.contains($0) != floatingOverrideWindowIDs.contains($0)
        }
      frameReconciler?.cancelAnimations(for: changedIDs)
    }
    let omittedIDs = Set(layoutsByID.values.flatMap(\.omittedWindowIDs))
      .union(windows.filter(\.isMinimized).map(\.id))
    frameReconciler?.retainWindows(liveIDs.subtracting(omittedIDs))
    currentTopology = topology
    layoutIDByWindowID = newLayoutIDByWindowID
    if let windowID = pendingFocusedWindowID {
      pendingFocusedWindowID = nil
      if liveIDs.contains(windowID) {
        windowDidFocus(windowID)
      }
    }
    for (id, attempt) in dwindleAttempts where dwindleContext(id) != attempt.context {
      frameReconciler?.cancelAnimations(for: attempt.context.tree?.windowIDs ?? [])
      dwindleAttempts.removeValue(forKey: id)
    }
    let unavailableIDs = Set(windows.filter(\.hasUnavailableFacts).map(\.id))
    if unavailableIDs != unavailableFactWindowIDs {
      unavailableFactWindowIDs = unavailableIDs
      factRetryInterval = 1
      factRetryCountdown = 1
    }
    updateMembershipPolling()
  }

  func addRule(_ rule: WindowRule) throws {
    try rules.appendUniquelyLabeled(rule, kind: "rule", label: \.label)
    reconcileAndReflowVisibleSpaces()
  }

  func removeRule(selector: String) throws {
    try rules.remove(selector: selector, kind: "rule", label: \.label)
    reconcileAndReflowVisibleSpaces()
  }

  func removeAllRules() {
    replaceRules([])
  }

  func replaceRules(_ rules: [WindowRule]) {
    self.rules = rules
    reconcileAndReflowVisibleSpaces()
  }

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

  func layoutState(for spaceID: UInt64) -> TilingLayoutState? {
    layoutIDs(for: spaceID).first.flatMap { layoutsByID[$0] }
  }

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

  func isWindowTiled(_ windowID: CGWindowID) -> Bool {
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }
    guard let state = layoutsByID[layoutID], state.selection != .float else { return false }
    return !floatingOverrideWindowIDs.contains(windowID)
      && !state.omittedWindowIDs.contains(windowID)
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

  func windowDidFocus(_ windowID: CGWindowID) {
    pendingFocusedWindowID = nil
    guard !floatingOverrideWindowIDs.contains(windowID) else { return }
    guard let layoutID = layoutIDByWindowID[windowID] else {
      pendingFocusedWindowID = windowID
      return
    }
    guard var state = layoutsByID[layoutID] else { return }

    state.focusedWindowID = windowID
    layoutsByID[layoutID] = state
  }

  func reconcileAndReflowVisibleSpaces() {
    scheduledReconcile?.cancel()
    scheduledReconcile = nil
    reconcile()
    reflowVisibleSpaces()
  }

  func scheduleReconcileAndReflow() {
    guard scheduledReconcile == nil else { return }
    scheduledReconcile = Task { @MainActor [weak self] in
      guard !Task.isCancelled, let self else { return }
      scheduledReconcile = nil
      reconcileAndReflowVisibleSpaces()
    }
  }

  func waitForScheduledReconcile() async {
    await scheduledReconcile?.value
  }

  func windowTitleDidChange(_ windowID: CGWindowID) {
    guard rules.contains(where: \.filtersTitle) else { return }
    guard let identity = ruleIdentity(windowID) else { return }
    guard WindowRuleActions.resolve(rules, for: identity) != ruleActionsByWindowID[windowID] else {
      return
    }
    scheduleReconcileAndReflow()
  }

  func waitForRuleSpaceMoves() async {
    while let task = ruleSpaceMoveTasks.values.first {
      await task.value
    }
  }

  func windowFrameDidChange(_ windowID: CGWindowID) {
    if frameReconciler?.shouldSuppressNotification(for: windowID) == true {
      return
    }
    guard !floatingOverrideWindowIDs.contains(windowID) else { return }
    if let id = layoutIDByWindowID[windowID], dwindleAttempts[id]?.verified == true {
      dwindleAttempts.removeValue(forKey: id)
    }
    scheduleReconcileAndReflow()
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
        hiding: hiddenWindowIDs(in: state)
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
        placement: state.masterPlacement
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
        settings: spaceSettings
      )
    }
  }

  private func applyRulePlacements(
    _ actions: [CGWindowID: WindowRuleActions],
    snapshot: TilingReconciliationSnapshot
  ) -> Set<CGWindowID> {
    guard let topology = snapshot.topology else { return [] }
    appliedRulePlacements = appliedRulePlacements.filter { actions[$0.key] != nil }
    var changedWindowIDs = Set<CGWindowID>()
    for window in snapshot.windows.sorted(by: { $0.id < $1.id }) {
      let desired = actions[window.id]?.placement ?? WindowRulePlacement()
      if desired.isEmpty {
        appliedRulePlacements.removeValue(forKey: window.id)
        continue
      }
      var applied = appliedRulePlacements[window.id] ?? WindowRulePlacement()
      if desired.grid == nil { applied.grid = nil }
      if desired.display == nil { applied.display = nil }
      if desired.space == nil { applied.space = nil }
      defer { appliedRulePlacements[window.id] = applied }
      guard ruleSpaceMoveTasks[window.id] == nil else { continue }
      var placement = WindowRulePlacement(
        grid: desired.grid != applied.grid ? desired.grid : nil,
        display: desired.display != applied.display ? desired.display : nil,
        space: desired.space != applied.space ? desired.space : nil
      )
      if placement.display != nil { placement.grid = desired.grid }
      guard !placement.isEmpty else { continue }
      guard !isInteractingWithWindow(window.id),
        !window.isMinimized, window.isMovable, window.subrole == "AXStandardWindow",
        let layoutID = topology.layoutID(for: window.id, on: window.displayID),
        topology.visibleLayoutIDs.contains(layoutID)
      else { continue }
      if let space = placement.space {
        let spaceIDs = ruleSpaceIDs()
        guard spaceIDs.indices.contains(space - 1),
          topology.spacesByID[spaceIDs[space - 1]]?.type == .normal
        else { continue }
        applied.space = space
        if spaceIDs[space - 1] != layoutID.spaceID {
          applied.grid = nil
          startRuleSpaceMove(window.id, to: space)
          continue
        }
        placement.space = nil
        guard !placement.isEmpty else { continue }
      }
      let destinationLayoutID: TilingLayoutID
      if let display = placement.display {
        guard let displayID = display.resolve(in: ruleDisplayIDs()),
          let target = topology.visibleLayoutIDs.first(where: { $0.displayID == displayID }
          )
        else { continue }
        destinationLayoutID = target
      } else {
        destinationLayoutID = layoutID
      }
      let selection = layoutsByID[destinationLayoutID]?.selection ?? defaultState.selection
      if !window.isResizable
        || (selection != .float && !floatingOverrideWindowIDs.contains(window.id))
      {
        placement.grid = nil
      }
      guard !placement.isEmpty else { continue }
      prepareForSynchronousMutation(for: window.id)
      switch rulePlacement(placement, window.id, destinationLayoutID) {
      case .deferred:
        continue
      case .applied, .failed:
        changedWindowIDs.insert(window.id)
      }
      if let display = placement.display {
        applied.display = display
        applied.grid = nil
      }
      if let grid = placement.grid { applied.grid = grid }
    }
    return changedWindowIDs
  }

  private func startRuleSpaceMove(_ windowID: CGWindowID, to index: Int) {
    prepareForSynchronousMutation(for: windowID)
    ruleSpaceMoveTasks[windowID] = Task { [weak self, ruleSpaceMove] in
      do {
        try await ruleSpaceMove(windowID, index)
      } catch {
        if !(error is CancellationError) {
          log("rule space move failed for window \(windowID): \(error)", level: .warn)
        }
      }
      guard let self else { return }
      ruleSpaceMoveTasks.removeValue(forKey: windowID)
      if !Task.isCancelled { reconcileAndReflowVisibleSpaces() }
    }
  }

  private func reflowIfMembershipChanged() {
    let membership = windowSpaceMembership()
    let previousMembership = currentTopology?.spaceIDsByWindowID ?? [:]
    guard currentTopology == nil || membership != previousMembership else {
      retryUnavailableFacts()
      return
    }

    let changedWindowIDs = Set(membership.keys).union(previousMembership.keys).filter {
      membership[$0] != previousMembership[$0]
    }
    for windowID in changedWindowIDs.sorted() {
      if let window = windows?.window(by: windowID) {
        log("window space membership changed \(window)")
      } else {
        log("window space membership changed id: \(windowID)")
      }
    }

    reconcileAndReflowVisibleSpaces()
  }

  private func retryUnavailableFacts() {
    guard !unavailableFactWindowIDs.isEmpty else { return }
    factRetryCountdown -= 1
    guard factRetryCountdown <= 0 else { return }

    factRetryInterval = min(factRetryInterval * 2, Self.maximumFactRetryInterval)
    factRetryCountdown = factRetryInterval
    let recoveredWindowIDs = unavailableFactWindowIDs.subtracting(
      unavailableFacts(unavailableFactWindowIDs)
    )
    guard !recoveredWindowIDs.isEmpty else { return }

    for windowID in recoveredWindowIDs.sorted() {
      log("window accessibility facts available id: \(windowID)")
    }
    reconcileAndReflowVisibleSpaces()
  }

  private func suspendTopology() {
    frameReconciler?.cancelAnimations()
    currentTopology = nil
    dwindleAttempts.removeAll()
    updateMembershipPolling()
  }

  private func updateMembershipPolling() {
    guard
      defaultState.selection != .float
        || layoutsByID.values.contains(where: { $0.selection != .float })
    else {
      membershipPollingTask?.cancel()
      membershipPollingTask = nil
      return
    }
    guard membershipPollingTask == nil else { return }

    membershipPollingTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: .milliseconds(250))
        } catch {
          return
        }

        self?.reflowIfMembershipChanged()
      }
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

  private func applyPlans(for layoutIDs: some Sequence<TilingLayoutID>) {
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

  private func dwindleContext(_ id: TilingLayoutID) -> DwindleContext? {
    guard let state = layoutsByID[id], state.selection == .dwindle,
      let topology = currentTopology, topology.visibleLayoutIDs.contains(id),
      let display = topology.displaysByID[id.displayID]
    else { return nil }
    return DwindleContext(
      tree: activeTree(of: state),
      bounds: display.visibleFrame,
      settings: spaces.settings(for: id.spaceID)
    )
  }

  private func applyDwindle(_ id: TilingLayoutID, frames: [CGWindowID: CGRect]) {
    guard let context = dwindleContext(id), !frames.isEmpty else { return }
    if dwindleAttempts[id]?.context == context { return }
    let attempt = DwindleAttempt(context: context)
    dwindleAttempts[id] = attempt

    frameReconciler?.apply(frames) { [weak self] results in
      guard let self, self.dwindleAttempts[id] === attempt,
        self.dwindleContext(id) == attempt.context
      else { return }
      attempt.verified = results.values.allSatisfy { $0 }
      if !attempt.verified { self.logUnsatisfiedDwindle(id) }
    }
  }

  private func logUnsatisfiedDwindle(_ id: TilingLayoutID) {
    log("dwindle layout unsatisfied space=\(id.spaceID)", level: .warn)
  }

  private func retryDwindle(_ ids: some Sequence<TilingLayoutID>) {
    for id in ids {
      dwindleAttempts.removeValue(forKey: id)
      frameReconciler?.cancelAnimations(for: layoutsByID[id]?.tree?.windowIDs ?? [])
    }
  }

  private func initialState(
    for layoutID: TilingLayoutID,
    previousLayoutsByID: [TilingLayoutID: TilingLayoutState]
  ) -> TilingLayoutState {
    var state =
      previousLayoutsByID
      .filter { $0.key.spaceID == layoutID.spaceID }
      .min { $0.key.displayID < $1.key.displayID }?
      .value ?? defaultState
    state.tree = nil
    state.omittedWindowIDs = []
    state.focusedWindowID = nil
    return state
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

  private func activeTree(of state: TilingLayoutState) -> TilingTree? {
    state.tree?.removing(hiddenWindowIDs(in: state))
  }

  private func hiddenWindowIDs(in state: TilingLayoutState) -> Set<CGWindowID> {
    state.omittedWindowIDs.union(floatingOverrideWindowIDs)
  }

  private func hiddenWindowIDs(inLayoutContaining windowID: CGWindowID) -> Set<CGWindowID> {
    layoutIDByWindowID[windowID].flatMap { layoutsByID[$0] }.map(hiddenWindowIDs(in:)) ?? []
  }

  private func availableWindowIDs(in state: TilingLayoutState, floating: Bool) -> [CGWindowID] {
    (state.tree?.windowIDs ?? []).filter { windowID in
      guard !state.omittedWindowIDs.contains(windowID) else { return false }
      return state.selection == .float
        || floatingOverrideWindowIDs.contains(windowID) == floating
    }
  }

  private func layoutIDs(for spaceID: UInt64) -> [TilingLayoutID] {
    layoutsByID.keys.filter { $0.spaceID == spaceID }.sorted()
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

struct TilingReconciliationSnapshot {
  let windows: [TilingWindowSnapshot]

  let topology: SpaceTopology?
}

private struct DwindleContext: Equatable {
  let tree: TilingTree?
  let bounds: CGRect
  let settings: SpaceSettings
}

private final class DwindleAttempt {
  let context: DwindleContext
  var verified = false

  init(context: DwindleContext) { self.context = context }
}
