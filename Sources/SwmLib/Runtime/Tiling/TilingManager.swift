import CoreGraphics

/// Owns automatic-tiling state and reconciles it from coherent topology snapshots.
@MainActor
public final class TilingManager {
  typealias SnapshotProvider = () -> TilingReconciliationSnapshot

  private let masterLayout = MasterLayout()
  private let dwindleLayout = DwindleLayout()
  private let snapshot: SnapshotProvider
  private let spaceManager: SpaceManager
  private let frameReconciler: WindowFrameReconciler?
  private var currentTopology: SpaceTopology?
  private var defaultSelection = LayoutSelection.float
  private var defaultMasterRatio: CGFloat = 0.5
  private var defaultMasterPlacement = MasterPlacement.left
  private var defaultPreserveSplitDirections = false
  private var floatingOverrideWindowIDs = Set<CGWindowID>()
  private var layoutIDByWindowID = [CGWindowID: SpaceLayoutID]()
  private var layoutsByID = [SpaceLayoutID: SpaceLayoutState]()

  /// Create a manager backed by the live runtime models.
  public convenience init(windowManager: WindowManager, spaceManager: SpaceManager) {
    self.init(
      snapshot: {
        let windows = windowManager.allWindows().map { $0.tilingSnapshot() }
        return TilingReconciliationSnapshot(
          windows: windows,
          topology: spaceManager.snapshotTopology(for: windows.map(\.id))
        )
      },
      spaceManager: spaceManager,
      frameReconciler: WindowFrameReconciler(
        currentFrame: { windowManager.window(by: $0)?.frame() },
        frameMutation: { windowID, targetFrame, currentFrame in
          windowManager.window(by: windowID)?.setFrame(targetFrame, from: currentFrame)
        }
      )
    )
  }

  /// Create a manager with an injectable reconciliation snapshot.
  init(
    snapshot: @escaping SnapshotProvider,
    spaceManager: SpaceManager,
    frameReconciler: WindowFrameReconciler? = nil
  ) {
    self.snapshot = snapshot
    self.spaceManager = spaceManager
    self.frameReconciler = frameReconciler
  }

  /// Seed and reconcile all per-Space state from the current runtime inventory.
  public func start() {
    reconcile()
    reflowVisibleSpaces()
  }

  /// Reconcile retained layouts, membership, and dispositions from one fresh snapshot.
  func reconcile() {
    let snapshot = snapshot()
    let windows = snapshot.windows.sorted { $0.id < $1.id }
    floatingOverrideWindowIDs.formIntersection(windows.map(\.id))
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

    var retainedWindowIDsByLayoutID = [SpaceLayoutID: Set<CGWindowID>]()
    var omittedWindowIDsByLayoutID = [SpaceLayoutID: Set<CGWindowID>]()
    var newLayoutIDByWindowID = [CGWindowID: SpaceLayoutID]()

    for window in windows {
      let disposition = WindowEligibilityPolicy.disposition(for: window, topology: topology)
      let placement: (layoutID: SpaceLayoutID, isOmitted: Bool)

      switch disposition {
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

      let retainedWindowIDs = state.tree?.windowIDs ?? []
      for windowID in retainedWindowIDs where !desiredWindowIDs.contains(windowID) {
        state.tree = state.tree?.removing([windowID])
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

      if let focusedWindowID = state.focusedWindowID,
        !desiredWindowIDs.contains(focusedWindowID)
      {
        state.focusedWindowID = nil
      }

      state.omittedWindowIDs = omittedWindowIDsByLayoutID[layoutID] ?? []
      layoutsByID[layoutID] = state
    }

    currentTopology = topology
    layoutIDByWindowID = newLayoutIDByWindowID
  }

  /// Select floating or an automatic layout for a known normal Space.
  @discardableResult
  func setLayout(_ selection: LayoutSelection, for spaceID: UInt64) -> Bool {
    let layoutIDs = layoutIDs(for: spaceID)
    guard !layoutIDs.isEmpty else { return false }

    for layoutID in layoutIDs {
      layoutsByID[layoutID]?.selection = selection
    }
    if selection != .float {
      reflow(spaceID: spaceID)
    }
    return true
  }

  /// Select floating or an automatic layout for all current and future Spaces.
  func setLayoutForSpaces(_ selection: LayoutSelection) {
    defaultSelection = selection

    layoutsByID = layoutsByID.mapValues { currentState in
      var state = currentState
      state.selection = selection
      return state
    }
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
    applyMasterPlans(for: layoutIDs)
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
    reflowVisibleMasterLayouts()
  }

  /// Set the master placement for one Space.
  @discardableResult
  func setMasterPlacement(_ placement: MasterPlacement, for spaceID: UInt64) -> Bool {
    let layoutIDs = layoutIDs(for: spaceID)
    guard !layoutIDs.isEmpty else { return false }

    for layoutID in layoutIDs {
      layoutsByID[layoutID]?.masterPlacement = placement
    }
    applyMasterPlans(for: layoutIDs)
    return true
  }

  /// Set the default master placement for all current and future Spaces.
  func setMasterPlacementForAllSpaces(_ placement: MasterPlacement) {
    defaultMasterPlacement = placement
    layoutsByID = layoutsByID.mapValues { currentState in
      var state = currentState
      state.masterPlacement = placement
      return state
    }
    reflowVisibleMasterLayouts()
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
    applyDwindlePlans(for: layoutIDs)
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
    reflowVisibleDwindleLayouts()
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
    guard var tree = state.tree, let masterWindowID = tree.windowIDs.first else { return false }
    guard tree.swap(windowID, with: masterWindowID) else { return false }

    state.tree = tree
    state.focusedWindowID = windowID
    layoutsByID[layoutID] = state
    applyPlans(for: [layoutID])
    return true
  }

  /// Set a window's explicit floating or tiled participation.
  @discardableResult
  func setWindowLayout(_ selection: WindowLayoutSelection, for windowID: CGWindowID) -> Bool {
    guard let topology = currentTopology else { return false }
    guard topology.normalSpaceIDs(for: windowID).count == 1 else { return false }
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }

    switch selection {
    case .float:
      floatingOverrideWindowIDs.insert(windowID)
      if layoutsByID[layoutID]?.focusedWindowID == windowID {
        layoutsByID[layoutID]?.focusedWindowID = nil
      }
    case .tile:
      floatingOverrideWindowIDs.remove(windowID)
    case .toggle:
      if floatingOverrideWindowIDs.remove(windowID) == nil {
        floatingOverrideWindowIDs.insert(windowID)
        if layoutsByID[layoutID]?.focusedWindowID == windowID {
          layoutsByID[layoutID]?.focusedWindowID = nil
        }
      }
    }
    applyPlans(for: [layoutID])
    return true
  }

  /// Return the next available window in stable layout order.
  func cycledWindowID(from windowID: CGWindowID, in direction: CycleDirection)
    -> CGWindowID?
  {
    guard let layoutID = layoutIDByWindowID[windowID] else { return nil }
    guard let state = layoutsByID[layoutID], let tree = state.tree else { return nil }
    let windowIDs = tree.windowIDs.filter { candidateWindowID in
      guard !state.omittedWindowIDs.contains(candidateWindowID) else { return false }
      return state.selection == .float || !floatingOverrideWindowIDs.contains(candidateWindowID)
    }
    guard windowIDs.count > 1, let index = windowIDs.firstIndex(of: windowID) else { return nil }

    switch direction {
    case .next:
      return windowIDs[(index + 1) % windowIDs.count]
    case .prev:
      return windowIDs[(index - 1 + windowIDs.count) % windowIDs.count]
    }
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

  /// Update the insertion anchor for the focused window's tiled Space.
  func windowDidFocus(_ windowID: CGWindowID) {
    guard !floatingOverrideWindowIDs.contains(windowID) else { return }
    guard let layoutID = layoutIDByWindowID[windowID] else { return }
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
  func layoutPlan(for layoutID: SpaceLayoutID) -> TilingLayoutPlan {
    guard var state = layoutsByID[layoutID] else { return .unknownSpace }
    guard state.selection != .float else { return .disabled }
    guard let topology = currentTopology else { return .unknownSpace }
    guard topology.visibleLayoutIDs.contains(layoutID) else { return .notVisible }
    guard let display = topology.displaysByID[layoutID.displayID] else { return .unknownSpace }

    let omittedWindowIDs = state.omittedWindowIDs.union(floatingOverrideWindowIDs)
    let spaceSettings = spaceManager.settings(for: layoutID.spaceID)
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

  /// Apply actionable plans for a stable sequence of layouts.
  private func applyPlans(for layoutIDs: some Sequence<SpaceLayoutID>) {
    for layoutID in layoutIDs {
      guard case .layout(.frames(let frames)) = layoutPlan(for: layoutID) else { continue }
      frameReconciler?.apply(frames)
    }
  }

  /// Create empty layout state, inheriting per-Space controls when a display changes.
  private func initialState(
    for layoutID: SpaceLayoutID,
    previousLayoutsByID: [SpaceLayoutID: SpaceLayoutState]
  ) -> SpaceLayoutState {
    let inheritedState =
      previousLayoutsByID
      .filter { $0.key.spaceID == layoutID.spaceID }
      .min { $0.key.displayID < $1.key.displayID }?
      .value

    return SpaceLayoutState(
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
  private func layoutIDs(for spaceID: UInt64) -> [SpaceLayoutID] {
    sorted(layoutsByID.keys.filter { $0.spaceID == spaceID })
  }

  /// Swap complete frames for neighbouring windows outside automatic layout geometry.
  private func swapFloatingWindow(
    _ windowID: CGWindowID,
    in direction: CardinalDirection,
    layoutID: SpaceLayoutID,
    state: SpaceLayoutState
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

  /// Apply fresh master plans for every visible master layout.
  private func reflowVisibleMasterLayouts() {
    guard let currentTopology else { return }
    applyMasterPlans(for: sorted(currentTopology.visibleLayoutIDs))
  }

  /// Apply fresh plans only where the master settings affect geometry.
  private func applyMasterPlans(for layoutIDs: some Sequence<SpaceLayoutID>) {
    applyPlans(for: layoutIDs.filter { layoutsByID[$0]?.selection == .master })
  }

  /// Apply fresh dwindle plans for every visible dwindle layout.
  private func reflowVisibleDwindleLayouts() {
    guard let currentTopology else { return }
    applyDwindlePlans(for: sorted(currentTopology.visibleLayoutIDs))
  }

  /// Apply fresh plans only where dwindle settings affect geometry.
  private func applyDwindlePlans(for layoutIDs: some Sequence<SpaceLayoutID>) {
    applyPlans(for: layoutIDs.filter { layoutsByID[$0]?.selection == .dwindle })
  }

  /// Sort composite IDs for deterministic reconciliation and frame application.
  private func sorted(_ layoutIDs: some Sequence<SpaceLayoutID>) -> [SpaceLayoutID] {
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
