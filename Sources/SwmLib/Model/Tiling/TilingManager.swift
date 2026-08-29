import CoreGraphics

/// Owns automatic-tiling state and reconciles it from coherent topology snapshots.
@MainActor
public final class TilingManager {
  typealias SnapshotProvider = () -> TilingReconciliationSnapshot

  private let masterLayout = MasterLayout()
  private let dwindleLayout = DwindleLayout()
  private let snapshot: SnapshotProvider
  private let spaceManager: SpaceManager
  private var frameReconciler: WindowFrameReconciler?
  private var currentTopology: SpaceTopology?
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
      spaceManager: spaceManager
    )
    frameReconciler = WindowFrameReconciler(
      currentFrame: { windowManager.window(by: $0)?.frame() },
      frameMutation: { windowID, targetFrame, currentFrame in
        windowManager.window(by: windowID)?.setFrame(targetFrame, from: currentFrame)
      }
    )
  }

  /// Create a manager with an injectable reconciliation snapshot.
  init(
    snapshot: @escaping SnapshotProvider,
    spaceManager: SpaceManager
  ) {
    self.snapshot = snapshot
    self.spaceManager = spaceManager
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
    let topology = snapshot.topology
    let layoutIDs = topology.layoutIDs

    layoutsByID = layoutsByID.filter { layoutIDs.contains($0.key) }
    for layoutID in layoutIDs where layoutsByID[layoutID] == nil {
      layoutsByID[layoutID] = SpaceLayoutState(
        mode: .master,
        tree: nil,
        minimizedWindowIDs: [],
        focusedWindowID: nil,
        enabled: false
      )
    }

    var tiledWindowIDsByLayoutID = [SpaceLayoutID: Set<CGWindowID>]()
    var minimizedWindowIDsByLayoutID = [SpaceLayoutID: Set<CGWindowID>]()
    var newLayoutIDByWindowID = [CGWindowID: SpaceLayoutID]()

    for window in windows {
      guard WindowEligibilityPolicy.disposition(for: window, topology: topology) == .tiled else {
        continue
      }
      guard let layoutID = topology.layoutID(for: window.id, on: window.displayID) else {
        continue
      }
      tiledWindowIDsByLayoutID[layoutID, default: []].insert(window.id)
      newLayoutIDByWindowID[window.id] = layoutID
      if window.isMinimized {
        minimizedWindowIDsByLayoutID[layoutID, default: []].insert(window.id)
      }
    }

    for layoutID in layoutIDs {
      guard var state = layoutsByID[layoutID] else { continue }
      let desiredWindowIDs = tiledWindowIDsByLayoutID[layoutID] ?? []

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

      state.minimizedWindowIDs = minimizedWindowIDsByLayoutID[layoutID] ?? []
      layoutsByID[layoutID] = state
    }

    currentTopology = topology
    layoutIDByWindowID = newLayoutIDByWindowID
  }

  /// Enable or disable automatic frame planning for a known normal Space.
  @discardableResult
  func setEnabled(_ enabled: Bool, for spaceID: UInt64) -> Bool {
    let layoutIDs = layoutIDs(for: spaceID)
    guard !layoutIDs.isEmpty else { return false }

    for layoutID in layoutIDs {
      layoutsByID[layoutID]?.enabled = enabled
    }
    if enabled {
      reflow(spaceID: spaceID)
    }
    return true
  }

  /// Toggle automatic tiling for a known normal Space and return the new value.
  func toggleEnabled(for spaceID: UInt64) -> Bool? {
    let layoutIDs = layoutIDs(for: spaceID)
    guard !layoutIDs.isEmpty else { return nil }
    let enabled = !layoutIDs.allSatisfy { layoutsByID[$0]?.enabled == true }
    return setEnabled(enabled, for: spaceID) ? enabled : nil
  }

  /// Return whether automatic tiling is enabled for a known Space.
  func isEnabled(for spaceID: UInt64) -> Bool {
    let layoutIDs = layoutIDs(for: spaceID)
    return !layoutIDs.isEmpty && layoutIDs.allSatisfy { layoutsByID[$0]?.enabled == true }
  }

  /// Select the layout algorithm for a known normal Space.
  @discardableResult
  func setLayoutMode(_ mode: LayoutMode, for spaceID: UInt64) -> Bool {
    let layoutIDs = layoutIDs(for: spaceID)
    guard !layoutIDs.isEmpty else { return false }

    for layoutID in layoutIDs {
      layoutsByID[layoutID]?.mode = mode
    }
    if layoutIDs.contains(where: { layoutsByID[$0]?.enabled == true }) {
      reflow(spaceID: spaceID)
    }
    return true
  }

  /// Return the selected layout algorithm for a known Space.
  func layoutMode(for spaceID: UInt64) -> LayoutMode? {
    let modes = Set(layoutIDs(for: spaceID).compactMap { layoutsByID[$0]?.mode })
    guard modes.count == 1 else { return nil }
    return modes.first
  }

  /// Update the insertion anchor for the focused window's tiled Space.
  func windowDidFocus(_ windowID: CGWindowID) {
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

    reconcileAndReflowVisibleSpaces()
  }

  /// Apply a fresh plan for one Space when it is visible and enabled.
  func reflow(spaceID: UInt64) {
    for layoutID in layoutIDs(for: spaceID) {
      guard case .layout(.frames(let frames)) = layoutPlan(for: layoutID) else { continue }
      frameReconciler?.apply(frames)
    }
  }

  /// Apply fresh plans for all currently visible normal Spaces.
  func reflowVisibleSpaces() {
    guard let currentTopology else { return }

    for layoutID in sorted(currentTopology.visibleLayoutIDs) {
      guard case .layout(.frames(let frames)) = layoutPlan(for: layoutID) else { continue }
      frameReconciler?.apply(frames)
    }
  }

  /// Calculate the current plan for an enabled, visible layout without side effects.
  func layoutPlan(for layoutID: SpaceLayoutID) -> TilingLayoutPlan {
    guard let state = layoutsByID[layoutID] else { return .unknownSpace }
    guard state.enabled else { return .disabled }
    guard let topology = currentTopology else { return .unknownSpace }
    guard topology.visibleLayoutIDs.contains(layoutID) else { return .notVisible }
    guard let display = topology.displaysByID[layoutID.displayID] else { return .unknownSpace }

    let activeTree = state.tree?.removing(state.minimizedWindowIDs)
    let spaceSettings = spaceManager.settings(for: layoutID.spaceID)

    switch state.mode {
    case .master:
      return .layout(
        masterLayout.layout(
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

  /// Return stable layout IDs for a Space.
  private func layoutIDs(for spaceID: UInt64) -> [SpaceLayoutID] {
    sorted(layoutsByID.keys.filter { $0.spaceID == spaceID })
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

  /// Automatic tiling has not been explicitly enabled for the Space.
  case disabled

  /// Space exists but is not currently visible.
  case notVisible

  /// Pure engine result for the Space's active retained leaves.
  case layout(TilingLayoutResult)
}
