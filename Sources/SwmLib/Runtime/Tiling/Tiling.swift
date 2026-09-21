import CoreGraphics

/// Owns automatic-tiling state and reconciles it from coherent topology snapshots.
@MainActor
public final class Tiling {
  typealias RulePlacementHandler = (WindowRulePlacement, CGWindowID, TilingLayoutID) ->
    WindowRulePlacementResult
  typealias SnapshotProvider = () -> TilingReconciliationSnapshot
  typealias WindowSpaceMembershipProvider = () -> [CGWindowID: Set<UInt64>]

  /// Rules in registration order.
  private(set) var rules = [WindowRule]()

  private let masterLayout = MasterLayout()
  private let monocleLayout = MonocleLayout()
  private let dwindleLayout = DwindleLayout()
  private let snapshot: SnapshotProvider
  private let spaces: Spaces
  private let windows: Windows?
  private let frameReconciler: WindowFrameReconciler?
  private let windowSpaceMembership: WindowSpaceMembershipProvider
  private let ruleDisplayIDs: () -> [String]
  private let rulePlacement: RulePlacementHandler
  private var appliedRulePlacements = [CGWindowID: WindowRulePlacement]()
  private var currentTopology: SpaceTopology?
  private var defaultSelection = LayoutSelection.float
  private var defaultMasterRatio: CGFloat = 0.5
  private var defaultMasterPlacement = MasterPlacement.left
  private var defaultPreserveSplitDirections = false
  private var manualFloatingByWindowID = [CGWindowID: Bool]()
  private var floatingOverrideWindowIDs = Set<CGWindowID>()
  private var layoutIDByWindowID = [CGWindowID: TilingLayoutID]()
  private var fixedSizeLayoutIDByWindowID = [CGWindowID: TilingLayoutID]()
  private var layoutsByID = [TilingLayoutID: TilingLayoutState]()
  private var pendingFocusedWindowID: CGWindowID?
  private var membershipPollingTask: Task<Void, Never>?

  /// Create tiling backed by the live runtime models.
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
        frameMutation: { windowID, targetFrame, currentFrame in
          windows.window(by: windowID)?.setFrame(targetFrame, from: currentFrame)
        },
        delivery: AnimationFrameDelivery(windows: windows)
      ),
      windowSpaceMembership: {
        Dictionary(
          uniqueKeysWithValues: windows.allWindows().map { window in
            (window.id, Set(WindowServerClient.shared.spaceIDs(containing: window.id)))
          }
        )
      }
    )
  }

  /// Create tiling with an injectable reconciliation snapshot.
  init(
    snapshot: @escaping SnapshotProvider,
    spaces: Spaces,
    windows: Windows? = nil,
    frameReconciler: WindowFrameReconciler? = nil,
    windowSpaceMembership: WindowSpaceMembershipProvider? = nil,
    rulePlacement: RulePlacementHandler? = nil,
    ruleDisplayIDs: @escaping () -> [String] = { WindowRulePlacementApplier.displayIDs() }
  ) {
    self.ruleDisplayIDs = ruleDisplayIDs
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
      windowSpaceMembership ?? { snapshot().topology.spaceIDsByWindowID }
    if let windows {
      frameReconciler?.onInteractionEnded = { [weak self] in
        self?.reconcileAndReflowVisibleSpaces()
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
  }

  /// Seed and reconcile all per-Space state from the current runtime inventory.
  public func initialize() {
    reconcile()
    reflowVisibleSpaces()
  }

  /// Set the frame animation duration in seconds.
  func setAnimationDuration(_ duration: Double) {
    frameReconciler?.animationDuration = duration
  }

  /// Select the curve captured by newly started or retargeted animations.
  func setAnimationEasing(_ easing: AnimationEasing) {
    frameReconciler?.animationEasing = easing
  }

  /// Return the pending destination so repeated geometry commands accumulate.
  func destinationFrame(for windowID: CGWindowID) -> CGRect? {
    frameReconciler?.frames(for: [windowID])[windowID]
  }

  /// Animate a direct geometry command when the configured settings allow it.
  func animateFrame(_ frame: CGRect, for windowID: CGWindowID) -> Bool {
    guard let frameReconciler, frameReconciler.animationEnabled else { return false }
    frameReconciler.apply([windowID: frame])
    return true
  }

  /// Stop an animation before a direct window command changes its frame.
  func cancelAnimation(for windowID: CGWindowID) {
    frameReconciler?.cancelAnimations(for: [windowID])
  }

  func isInteractingWithWindow(_ windowID: CGWindowID) -> Bool {
    frameReconciler?.isInteracting(windowID) == true
  }

  /// Drain started writes before a command or placement changes the same window synchronously.
  func prepareForSynchronousMutation(for windowID: CGWindowID) {
    frameReconciler?.prepareForSynchronousMutation(for: windowID)
  }

  /// Invalidate destinations immediately when a topology event arrives.
  func cancelAnimations() {
    frameReconciler?.cancelAnimations()
  }

  /// Reconcile retained layouts, membership, and dispositions from one fresh snapshot.
  func reconcile() {
    var snapshot = snapshot()
    var windows = snapshot.windows.sorted { $0.id < $1.id }
    var liveIDs = Set(windows.map(\.id))
    let previousFloatingIDs = floatingOverrideWindowIDs
    manualFloatingByWindowID = manualFloatingByWindowID.filter { liveIDs.contains($0.key) }
    let actions = Dictionary(
      uniqueKeysWithValues: windows.map {
        ($0.id, WindowRuleActions.resolve(rules, for: $0))
      }
    )
    floatingOverrideWindowIDs = Set(
      windows.filter {
        manualFloatingByWindowID[$0.id] ?? (actions[$0.id]?.manage == false)
      }.map(\.id)
    )
    if applyRulePlacements(actions, snapshot: snapshot) {
      // Transfers must be reflected in membership and display facts before planning a layout.
      snapshot = self.snapshot()
      windows = snapshot.windows.sorted { $0.id < $1.id }
      liveIDs = Set(windows.map(\.id))
    }
    let topology = snapshot.topology
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
      let disposition = WindowEligibilityPolicy.disposition(for: window, topology: topology)
      let placement: (layoutID: TilingLayoutID, isOmitted: Bool)

      switch disposition {
      case .excluded(.notResizable):
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
          tree.insert(windowID, beside: insertionAnchor)
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
    updateMembershipPolling()
  }

  /// Add a rule and immediately update existing windows.
  func addRule(_ rule: WindowRule) throws {
    if let label = rule.label, rules.contains(where: { $0.label == label }) {
      throw IPCCommandError.invalidRequest("rule label already exists: \(label)")
    }
    rules.append(rule)
    reconcileAndReflowVisibleSpaces()
  }

  /// Remove a rule by one-based index or unique label.
  func removeRule(selector: String) throws {
    let index: Int?
    if let number = Int(selector) {
      guard number > 0 else { throw IPCCommandError.invalidRequest("rule not found: \(selector)") }
      index = number - 1
    } else {
      index = rules.firstIndex { $0.label == selector }
    }
    guard let index, rules.indices.contains(index) else {
      throw IPCCommandError.invalidRequest("rule not found: \(selector)")
    }
    rules.remove(at: index)
    reconcileAndReflowVisibleSpaces()
  }

  /// Select floating or an automatic layout for a known normal Space.
  @discardableResult
  func setLayout(_ selection: LayoutSelection, for spaceID: UInt64) -> Bool {
    let layoutIDs = layoutIDs(for: spaceID)
    guard !layoutIDs.isEmpty else { return false }

    for layoutID in layoutIDs {
      frameReconciler?.cancelAnimations(for: layoutsByID[layoutID]?.tree?.windowIDs ?? [])
      layoutsByID[layoutID]?.selection = selection
    }
    updateMembershipPolling()
    if selection != .float {
      reflow(spaceID: spaceID)
    }
    return true
  }

  /// Select floating or an automatic layout for all current and future Spaces.
  func setLayoutForSpaces(_ selection: LayoutSelection) {
    frameReconciler?.cancelAnimations()
    defaultSelection = selection

    layoutsByID = layoutsByID.mapValues { currentState in
      var state = currentState
      state.selection = selection
      return state
    }
    updateMembershipPolling()
    if selection != .float {
      reflowVisibleSpaces()
    }
  }

  /// Set or adjust the master ratio for one Space.
  @discardableResult
  func changeMasterRatio(_ change: LayoutRatioChange, for spaceID: UInt64) -> Bool {
    let layoutIDs = layoutIDs(for: spaceID)
    guard !layoutIDs.isEmpty else { return false }

    let ratio = change.applying(to: layoutsByID[layoutIDs[0]]?.masterRatio ?? defaultMasterRatio)
    for layoutID in layoutIDs {
      layoutsByID[layoutID]?.masterRatio = ratio
    }
    applyPlans(for: layoutIDs, matching: .master)
    return true
  }

  /// Set the default master ratio for all current and future Spaces.
  func setMasterRatioForAllSpaces(_ ratio: CGFloat) {
    let ratio = LayoutRatioChange.absolute(ratio).applying(to: defaultMasterRatio)
    defaultMasterRatio = ratio
    layoutsByID = layoutsByID.mapValues { currentState in
      var state = currentState
      state.masterRatio = ratio
      return state
    }
    reflowVisibleLayouts(matching: .master)
  }

  /// Set the master placement for one Space.
  @discardableResult
  func setMasterPlacement(_ placement: MasterPlacement, for spaceID: UInt64) -> Bool {
    let layoutIDs = layoutIDs(for: spaceID)
    guard !layoutIDs.isEmpty else { return false }

    for layoutID in layoutIDs {
      layoutsByID[layoutID]?.masterPlacement = placement
    }
    applyPlans(for: layoutIDs, matching: .master)
    return true
  }

  /// Cycle the master placement for one Space.
  @discardableResult
  func cycleMasterPlacement(
    _ direction: CycleDirection,
    for spaceID: UInt64
  ) -> MasterPlacement? {
    let layoutIDs = layoutIDs(for: spaceID)
    guard !layoutIDs.isEmpty else { return nil }

    let placement =
      (layoutsByID[layoutIDs[0]]?.masterPlacement ?? defaultMasterPlacement).cycled(in: direction)
    for layoutID in layoutIDs {
      layoutsByID[layoutID]?.masterPlacement = placement
    }
    applyPlans(for: layoutIDs, matching: .master)
    return placement
  }

  /// Set the default master placement for all current and future Spaces.
  func setMasterPlacementForAllSpaces(_ placement: MasterPlacement) {
    defaultMasterPlacement = placement
    layoutsByID = layoutsByID.mapValues { currentState in
      var state = currentState
      state.masterPlacement = placement
      return state
    }
    reflowVisibleLayouts(matching: .master)
  }

  /// Enable or disable retained dwindle split directions for one Space.
  @discardableResult
  func setSplitDirectionPreservation(_ enabled: Bool, for spaceID: UInt64) -> Bool {
    let layoutIDs = layoutIDs(for: spaceID)
    guard !layoutIDs.isEmpty else { return false }

    for layoutID in layoutIDs {
      guard var state = layoutsByID[layoutID] else { continue }
      state.preserveSplitDirections = enabled
      if !enabled {
        state.tree = state.tree?.clearingSplitDirections()
      }
      layoutsByID[layoutID] = state
    }
    applyPlans(for: layoutIDs, matching: .dwindle)
    return true
  }

  /// Set retained dwindle split directions for all current and future Spaces.
  func setSplitDirectionPreservationForAllSpaces(_ enabled: Bool) {
    defaultPreserveSplitDirections = enabled
    layoutsByID = layoutsByID.mapValues { currentState in
      var state = currentState
      state.preserveSplitDirections = enabled
      if !enabled {
        state.tree = state.tree?.clearingSplitDirections()
      }
      return state
    }
    reflowVisibleLayouts(matching: .dwindle)
  }

  /// Swap a window with its closest neighbour in a direction.
  @discardableResult
  func swapWindow(_ windowID: CGWindowID, in direction: CardinalDirection) -> Bool {
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }
    guard let state = layoutsByID[layoutID] else { return false }
    if state.selection == .float || floatingOverrideWindowIDs.contains(windowID) {
      return swapFloatingWindow(windowID, in: direction, layoutID: layoutID, state: state)
    }
    guard case .layout(.frames(let framesByWindowID)) = layoutPlan(for: layoutID) else {
      return false
    }
    guard let neighborWindowID = direction.neighbor(of: windowID, in: framesByWindowID) else {
      return false
    }
    guard var state = layoutsByID[layoutID], var tree = state.tree else { return false }
    guard tree.swap(windowID, with: neighborWindowID) else { return false }

    state.tree = tree
    state.focusedWindowID = windowID
    layoutsByID[layoutID] = state
    applyPlans(for: [layoutID])
    return true
  }

  /// Swap a tiled window with the current master pane.
  @discardableResult
  func swapWindowWithMaster(_ windowID: CGWindowID) -> Bool {
    guard !floatingOverrideWindowIDs.contains(windowID) else { return false }
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }
    guard var state = layoutsByID[layoutID], state.selection == .master else { return false }
    guard var tree = state.tree,
      let masterWindowID = masterWindowID(inLayoutContaining: windowID)
    else { return false }
    guard tree.swap(windowID, with: masterWindowID) else { return false }

    state.tree = tree
    state.focusedWindowID = windowID
    layoutsByID[layoutID] = state
    applyPlans(for: [layoutID])
    return true
  }

  /// Return the active master window in the selected window's layout.
  func masterWindowID(inLayoutContaining windowID: CGWindowID) -> CGWindowID? {
    guard let layoutID = layoutIDByWindowID[windowID] else { return nil }
    guard let state = layoutsByID[layoutID], state.selection == .master else { return nil }
    let unavailableWindowIDs = state.omittedWindowIDs.union(floatingOverrideWindowIDs)
    return state.tree?.removing(unavailableWindowIDs)?.windowIDs.first
  }

  /// Set a window's explicit floating or tiled participation.
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
    if shouldFloat {
      floatingOverrideWindowIDs.insert(windowID)
    } else {
      floatingOverrideWindowIDs.remove(windowID)
    }
    if shouldFloat, layoutsByID[layoutID]?.focusedWindowID == windowID {
      layoutsByID[layoutID]?.focusedWindowID = nil
    }
    applyPlans(for: [layoutID])
    return true
  }

  /// Return the next available window in stable layout order.
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
    var windowIDs = (state.tree?.windowIDs ?? []).filter { candidateID in
      guard !state.omittedWindowIDs.contains(candidateID) else { return false }
      return state.selection == .float || !floatingOverrideWindowIDs.contains(candidateID)
    }
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

  /// Swap a tiled window with its neighbour in stable layout order.
  @discardableResult
  func swapWindowInOrder(_ windowID: CGWindowID, in direction: CycleDirection) -> Bool {
    guard !floatingOverrideWindowIDs.contains(windowID) else { return false }
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }
    guard var state = layoutsByID[layoutID], state.selection != .float, var tree = state.tree else {
      return false
    }
    guard let neighborWindowID = cycledWindowID(from: windowID, in: direction) else {
      return false
    }
    guard tree.swap(windowID, with: neighborWindowID) else { return false }

    state.tree = tree
    state.focusedWindowID = windowID
    layoutsByID[layoutID] = state
    applyPlans(for: [layoutID])
    return true
  }

  /// Set or adjust the nearest dwindle split containing a tiled window.
  @discardableResult
  func changeDwindleSplitRatio(
    _ change: LayoutRatioChange,
    for windowID: CGWindowID
  ) -> CGFloat? {
    guard !floatingOverrideWindowIDs.contains(windowID) else { return nil }
    guard let layoutID = layoutIDByWindowID[windowID] else { return nil }
    guard var state = layoutsByID[layoutID], state.selection == .dwindle else { return nil }
    guard var tree = state.tree else { return nil }
    guard let ratio = tree.changeSplitRatio(change, containing: windowID) else {
      return nil
    }

    state.tree = tree
    layoutsByID[layoutID] = state
    applyPlans(for: [layoutID])
    return ratio
  }

  /// Toggle and retain the selected window's nearest dwindle split direction.
  @discardableResult
  func toggleDwindleSplit(for windowID: CGWindowID) -> Bool {
    guard !floatingOverrideWindowIDs.contains(windowID) else { return false }
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }
    guard layoutsByID[layoutID]?.selection == .dwindle else { return false }
    guard case .layout = layoutPlan(for: layoutID) else { return false }
    guard var state = layoutsByID[layoutID], var tree = state.tree else { return false }
    guard let display = currentTopology?.displaysByID[layoutID.displayID] else { return false }
    tree =
      dwindleLayout.resolvingSplitDirections(
        in: tree,
        bounds: display.visibleFrame,
        settings: spaces.settings(for: layoutID.spaceID)
      ) ?? tree
    guard tree.toggleSplitDirection(containing: windowID) else { return false }

    state.tree = tree
    layoutsByID[layoutID] = state
    applyPlans(for: [layoutID])
    return true
  }

  /// Exchange the selected window's nearest dwindle sibling subtrees.
  @discardableResult
  func swapDwindleSplit(for windowID: CGWindowID) -> Bool {
    guard !floatingOverrideWindowIDs.contains(windowID) else { return false }
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }
    guard var state = layoutsByID[layoutID], state.selection == .dwindle, var tree = state.tree
    else {
      return false
    }
    guard tree.swapSplit(containing: windowID) else { return false }

    state.tree = tree
    layoutsByID[layoutID] = state
    applyPlans(for: [layoutID])
    return true
  }

  /// Update the insertion anchor for the focused window's tiled Space.
  func windowDidFocus(_ windowID: CGWindowID) {
    pendingFocusedWindowID = nil
    guard !floatingOverrideWindowIDs.contains(windowID) else { return }
    guard let layoutID = layoutIDByWindowID[windowID] else {
      // Focus can arrive before WindowServer exposes a new window's Space membership.
      pendingFocusedWindowID = windowID
      return
    }
    guard var state = layoutsByID[layoutID] else { return }

    state.focusedWindowID = windowID
    layoutsByID[layoutID] = state
  }

  /// Reconcile current facts and apply every visible enabled Space plan.
  func reconcileAndReflowVisibleSpaces() {
    reconcile()
    reflowVisibleSpaces()
  }

  /// Suppress expected frame feedback or reconcile an external move or resize.
  func windowFrameDidChange(_ windowID: CGWindowID) {
    if frameReconciler?.shouldSuppressNotification(for: windowID) == true {
      return
    }
    guard !floatingOverrideWindowIDs.contains(windowID) else { return }

    reconcileAndReflowVisibleSpaces()
  }

  /// Apply a fresh plan for one Space when it is visible and enabled.
  func reflow(spaceID: UInt64) {
    applyPlans(for: layoutIDs(for: spaceID))
  }

  /// Apply fresh plans for all currently visible normal Spaces.
  func reflowVisibleSpaces() {
    guard let currentTopology else { return }
    applyPlans(for: sorted(currentTopology.visibleLayoutIDs))
  }

  /// Calculate the current plan for an enabled, visible layout without applying frames.
  func layoutPlan(for layoutID: TilingLayoutID) -> TilingLayoutPlan {
    guard var state = layoutsByID[layoutID] else { return .unknownSpace }
    guard state.selection != .float else { return .disabled }
    guard let topology = currentTopology else { return .unknownSpace }
    guard topology.visibleLayoutIDs.contains(layoutID) else { return .notVisible }
    guard let display = topology.displaysByID[layoutID.displayID] else { return .unknownSpace }

    let omittedWindowIDs = state.omittedWindowIDs.union(floatingOverrideWindowIDs)
    let spaceSettings = spaces.settings(for: layoutID.spaceID)
    if state.selection == .dwindle, state.preserveSplitDirections {
      state.tree = dwindleLayout.resolvingSplitDirections(
        in: state.tree,
        bounds: display.visibleFrame,
        settings: spaceSettings
      )
      layoutsByID[layoutID] = state
    }
    let activeTree = state.tree?.removing(omittedWindowIDs)

    switch state.selection {
    case .float:
      return .disabled
    case .master:
      return .layout(
        masterLayout.layout(
          windowIDs: activeTree?.windowIDs ?? [],
          in: display.visibleFrame,
          settings: spaceSettings,
          masterRatio: state.masterRatio,
          placement: state.masterPlacement
        )
      )
    case .monocle:
      return .layout(
        monocleLayout.layout(
          windowIDs: activeTree?.windowIDs ?? [],
          in: display.visibleFrame,
          settings: spaceSettings
        )
      )
    case .dwindle:
      return .layout(
        dwindleLayout.layout(
          tree: activeTree,
          in: display.visibleFrame,
          settings: spaceSettings
        )
      )
    }
  }

  /// Apply changed placement rules without snapping back windows on subsequent events.
  private func applyRulePlacements(
    _ actions: [CGWindowID: WindowRuleActions],
    snapshot: TilingReconciliationSnapshot
  ) -> Bool {
    appliedRulePlacements = appliedRulePlacements.filter { actions[$0.key] != nil }
    var changed = false
    for window in snapshot.windows.sorted(by: { $0.id < $1.id }) {
      let desired = actions[window.id]?.placement ?? WindowRulePlacement()
      if desired.isEmpty {
        appliedRulePlacements.removeValue(forKey: window.id)
        continue
      }
      var applied = appliedRulePlacements[window.id] ?? WindowRulePlacement()
      if desired.grid == nil { applied.grid = nil }
      if desired.display == nil { applied.display = nil }
      appliedRulePlacements[window.id] = applied
      var placement = WindowRulePlacement(
        grid: desired.grid != applied.grid ? desired.grid : nil,
        display: desired.display != applied.display ? desired.display : nil
      )
      if placement.display != nil { placement.grid = desired.grid }
      guard !placement.isEmpty else { continue }
      guard !isInteractingWithWindow(window.id),
        !window.isMinimized, window.isMovable, window.subrole == "AXStandardWindow",
        let layoutID = snapshot.topology.layoutID(for: window.id, on: window.displayID),
        snapshot.topology.visibleLayoutIDs.contains(layoutID)
      else { continue }
      let destinationLayoutID: TilingLayoutID
      if let display = placement.display {
        guard let displayID = display.resolve(in: ruleDisplayIDs()),
          let target = snapshot.topology.visibleLayoutIDs.first(where: { $0.displayID == displayID }
          )
        else { continue }
        destinationLayoutID = target
      } else {
        destinationLayoutID = layoutID
      }
      let selection = layoutsByID[destinationLayoutID]?.selection ?? defaultSelection
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
        // Record rejected mutations too, so their frame notifications cannot trigger retries.
        changed = true
        layoutIDByWindowID.removeValue(forKey: window.id)
      }
      if let display = placement.display {
        applied.display = display
        // A grid from the old display is not a completed placement on the new one.
        applied.grid = nil
      }
      if let grid = placement.grid { applied.grid = grid }
      appliedRulePlacements[window.id] = applied
    }
    return changed
  }

  /// Reflow when authoritative WindowServer membership changed without a lifecycle event.
  private func reflowIfMembershipChanged() {
    let membership = windowSpaceMembership()
    let previousMembership = currentTopology?.spaceIDsByWindowID ?? [:]
    guard membership != previousMembership else { return }

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

  /// Poll membership while automatic tiling is active because Mission Control emits no event.
  private func updateMembershipPolling() {
    guard layoutsByID.values.contains(where: { $0.selection != .float }) else {
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

  /// Apply actionable plans for a stable sequence of layouts.
  private func applyPlans(for layoutIDs: some Sequence<TilingLayoutID>) {
    for layoutID in layoutIDs {
      guard case .layout(.frames(let frames)) = layoutPlan(for: layoutID) else { continue }
      frameReconciler?.apply(frames)
    }
  }

  /// Create empty layout state, inheriting per-Space controls when a display changes.
  private func initialState(
    for layoutID: TilingLayoutID,
    previousLayoutsByID: [TilingLayoutID: TilingLayoutState]
  ) -> TilingLayoutState {
    let inheritedState =
      previousLayoutsByID
      .filter { $0.key.spaceID == layoutID.spaceID }
      .min { $0.key.displayID < $1.key.displayID }?
      .value

    return TilingLayoutState(
      selection: inheritedState?.selection ?? defaultSelection,
      masterRatio: inheritedState?.masterRatio ?? defaultMasterRatio,
      masterPlacement: inheritedState?.masterPlacement ?? defaultMasterPlacement,
      preserveSplitDirections: inheritedState?.preserveSplitDirections
        ?? defaultPreserveSplitDirections,
      tree: nil,
      omittedWindowIDs: [],
      focusedWindowID: nil
    )
  }

  /// Return stable layout IDs for a Space.
  private func layoutIDs(for spaceID: UInt64) -> [TilingLayoutID] {
    sorted(layoutsByID.keys.filter { $0.spaceID == spaceID })
  }

  /// Swap complete frames for neighbouring windows outside automatic layout geometry.
  private func swapFloatingWindow(
    _ windowID: CGWindowID,
    in direction: CardinalDirection,
    layoutID: TilingLayoutID,
    state: TilingLayoutState
  ) -> Bool {
    guard currentTopology?.visibleLayoutIDs.contains(layoutID) == true else { return false }
    guard let frameReconciler else { return false }

    let candidateWindowIDs = (state.tree?.windowIDs ?? []).filter { candidateWindowID in
      guard !state.omittedWindowIDs.contains(candidateWindowID) else { return false }
      return state.selection == .float || floatingOverrideWindowIDs.contains(candidateWindowID)
    }
    let framesByWindowID = frameReconciler.frames(for: candidateWindowIDs)
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

  /// Apply fresh plans for every visible layout with the selected kind.
  private func reflowVisibleLayouts(matching selection: LayoutSelection) {
    guard let currentTopology else { return }
    applyPlans(for: sorted(currentTopology.visibleLayoutIDs), matching: selection)
  }

  /// Apply fresh plans only where the selected layout settings affect geometry.
  private func applyPlans(
    for layoutIDs: some Sequence<TilingLayoutID>,
    matching selection: LayoutSelection
  ) {
    applyPlans(for: layoutIDs.filter { layoutsByID[$0]?.selection == selection })
  }

  /// Sort composite IDs for deterministic reconciliation and frame application.
  private func sorted(_ layoutIDs: some Sequence<TilingLayoutID>) -> [TilingLayoutID] {
    layoutIDs.sorted {
      if $0.spaceID != $1.spaceID {
        return $0.spaceID < $1.spaceID
      }
      return $0.displayID < $1.displayID
    }
  }
}

/// Coherent runtime facts consumed by one tiling reconciliation.
struct TilingReconciliationSnapshot {
  /// Current manageable window facts.
  let windows: [TilingWindowSnapshot]

  /// Space membership and visible display topology for those windows.
  let topology: SpaceTopology
}

/// Explainable result of asking the runtime coordinator for Space geometry.
enum TilingLayoutPlan: Equatable {
  /// Space is not part of the current normal-Space topology.
  case unknownSpace

  /// The Space is using unmanaged floating layout.
  case disabled

  /// Space exists but is not currently visible.
  case notVisible

  /// Pure engine result for the Space's active retained leaves.
  case layout(TilingLayoutResult)
}
