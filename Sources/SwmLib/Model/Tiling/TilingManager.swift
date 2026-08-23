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
  private var layoutsBySpaceID = [UInt64: SpaceLayoutState]()
  private var tiledSpaceIDByWindowID = [CGWindowID: UInt64]()

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
    let normalSpaceIDs = Set(
      topology.spacesByID.values.filter { $0.type == .normal }.map(\.id)
    )

    layoutsBySpaceID = layoutsBySpaceID.filter { normalSpaceIDs.contains($0.key) }
    for descriptor in topology.spacesByID.values where descriptor.type == .normal {
      if layoutsBySpaceID[descriptor.id] == nil {
        layoutsBySpaceID[descriptor.id] = SpaceLayoutState(
          displayID: descriptor.displayID,
          mode: .master,
          layout: OrderedWindowLayout(),
          minimizedWindowIDs: [],
          focusedWindowID: nil,
          enabled: false
        )
      } else {
        layoutsBySpaceID[descriptor.id]?.displayID = descriptor.displayID
      }
    }

    var tiledWindowIDsBySpaceID = [UInt64: Set<CGWindowID>]()
    var minimizedWindowIDsBySpaceID = [UInt64: Set<CGWindowID>]()
    var tiledSpaceIDByWindowID = [CGWindowID: UInt64]()

    for window in windows {
      let normalMembership = topology.normalSpaceIDs(for: window.id)

      switch WindowEligibilityPolicy.disposition(for: window, topology: topology) {
      case .tiled:
        guard let spaceID = normalMembership.first else { continue }
        tiledWindowIDsBySpaceID[spaceID, default: []].insert(window.id)
        tiledSpaceIDByWindowID[window.id] = spaceID
        if window.isMinimized {
          minimizedWindowIDsBySpaceID[spaceID, default: []].insert(window.id)
        }
      case .floating, .excluded, .pending:
        break
      }
    }

    for spaceID in normalSpaceIDs {
      guard var state = layoutsBySpaceID[spaceID] else { continue }
      let desiredWindowIDs = tiledWindowIDsBySpaceID[spaceID] ?? []

      let retainedWindowIDs = state.layout.windowIDs
      for windowID in retainedWindowIDs where !desiredWindowIDs.contains(windowID) {
        state.layout.remove(windowID)
      }

      var insertionAnchor = state.focusedWindowID
      for windowID in desiredWindowIDs.sorted() where !state.layout.windowIDs.contains(windowID) {
        state.layout.insert(windowID, after: insertionAnchor)
        insertionAnchor = windowID
      }

      if let focusedWindowID = state.focusedWindowID,
        !desiredWindowIDs.contains(focusedWindowID)
      {
        state.focusedWindowID = nil
      }

      state.minimizedWindowIDs = minimizedWindowIDsBySpaceID[spaceID] ?? []
      layoutsBySpaceID[spaceID] = state
    }

    currentTopology = topology
    self.tiledSpaceIDByWindowID = tiledSpaceIDByWindowID
  }

  /// Enable or disable automatic frame planning for a known normal Space.
  @discardableResult
  func setEnabled(_ enabled: Bool, for spaceID: UInt64) -> Bool {
    guard var state = layoutsBySpaceID[spaceID] else { return false }
    state.enabled = enabled
    layoutsBySpaceID[spaceID] = state
    if enabled {
      reflow(spaceID: spaceID)
    }
    return true
  }

  /// Toggle automatic tiling for a known normal Space and return the new value.
  func toggleEnabled(for spaceID: UInt64) -> Bool? {
    guard let state = layoutsBySpaceID[spaceID] else { return nil }
    let enabled = !state.enabled
    return setEnabled(enabled, for: spaceID) ? enabled : nil
  }

  /// Return whether automatic tiling is enabled for a known Space.
  func isEnabled(for spaceID: UInt64) -> Bool {
    layoutsBySpaceID[spaceID]?.enabled ?? false
  }

  /// Select the layout algorithm for a known normal Space.
  @discardableResult
  func setLayoutMode(_ mode: LayoutMode, for spaceID: UInt64) -> Bool {
    guard var state = layoutsBySpaceID[spaceID] else { return false }
    state.mode = mode
    layoutsBySpaceID[spaceID] = state
    if state.enabled {
      reflow(spaceID: spaceID)
    }
    return true
  }

  /// Return the selected layout algorithm for a known Space.
  func layoutMode(for spaceID: UInt64) -> LayoutMode? {
    layoutsBySpaceID[spaceID]?.mode
  }

  /// Update the insertion anchor for the focused window's tiled Space.
  func windowDidFocus(_ windowID: CGWindowID) {
    guard let spaceID = tiledSpaceIDByWindowID[windowID] else { return }
    guard var state = layoutsBySpaceID[spaceID] else { return }

    state.focusedWindowID = windowID
    layoutsBySpaceID[spaceID] = state
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
    guard case .layout(.frames(let frames)) = layoutPlan(for: spaceID) else { return }
    frameReconciler?.apply(frames)
  }

  /// Apply fresh plans for all currently visible normal Spaces.
  func reflowVisibleSpaces() {
    guard let currentTopology else { return }

    for spaceID in currentTopology.visibleNormalSpaceIDs.sorted() {
      reflow(spaceID: spaceID)
    }
  }

  /// Calculate the current plan for an enabled, visible Space without side effects.
  func layoutPlan(for spaceID: UInt64) -> TilingLayoutPlan {
    guard let state = layoutsBySpaceID[spaceID] else { return .unknownSpace }
    guard state.enabled else { return .disabled }
    guard let topology = currentTopology else { return .unknownSpace }
    guard topology.visibleNormalSpaceIDs.contains(spaceID) else { return .notVisible }
    guard let display = topology.displaysByID[state.displayID] else {
      return .unresolvedDisplay
    }

    let windowIDs = state.layout.activeWindowIDs(
      excluding: state.minimizedWindowIDs
    )
    let spaceSettings = spaceManager.settings(for: spaceID)

    switch state.mode {
    case .master:
      return .layout(
        masterLayout.layout(
          windowIDs: windowIDs,
          in: display.visibleFrame,
          settings: spaceSettings
        )
      )
    case .dwindle:
      return .layout(
        dwindleLayout.layout(
          windowIDs: windowIDs,
          in: display.visibleFrame,
          settings: spaceSettings
        )
      )
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

  /// WindowServer display ownership cannot yet be mapped to physical bounds.
  case unresolvedDisplay

  /// Pure engine result for the Space's active retained leaves.
  case layout(TilingLayoutResult)
}
