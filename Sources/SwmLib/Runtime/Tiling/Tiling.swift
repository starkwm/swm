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

  static let maximumFactRetryInterval = 16

  var rules = [WindowRule]()

  let masterLayout = MasterLayout()
  let monocleLayout = MonocleLayout()
  let dwindleLayout = DwindleLayout()
  let snapshot: SnapshotProvider
  let spaces: Spaces
  let windows: Windows?
  let frameReconciler: WindowFrameReconciler?
  let windowSpaceMembership: WindowSpaceMembershipProvider
  let unavailableFacts: UnavailableFactsProvider
  let ruleIdentity: RuleIdentityProvider
  let ruleDisplayIDs: () -> [String]
  let rulePlacement: RulePlacementHandler
  let ruleSpaceIDs: () -> [UInt64]
  let ruleSpaceMove: RuleSpaceMoveHandler
  var appliedRulePlacements = [CGWindowID: WindowRulePlacement]()
  var ruleActionsByWindowID = [CGWindowID: WindowRuleActions]()
  var scheduledReconcile: Task<Void, Never>?
  var ruleSpaceMoveTasks = [CGWindowID: Task<Void, Never>]()
  var currentTopology: SpaceTopology?
  var defaultState = TilingLayoutState(
    selection: .float,
    masterRatio: 0.5,
    masterPlacement: .left,
    splitRatio: 0.5,
    preserveSplitDirections: false,
    tree: nil,
    omittedWindowIDs: [],
    focusedWindowID: nil
  )
  var manualFloatingByWindowID = [CGWindowID: Bool]()
  var floatingOverrideWindowIDs = Set<CGWindowID>()
  var layoutIDByWindowID = [CGWindowID: TilingLayoutID]()
  var fixedSizeLayoutIDByWindowID = [CGWindowID: TilingLayoutID]()
  var dispositionByWindowID = [CGWindowID: WindowDisposition]()
  var minimumSizeByWindowID = [CGWindowID: CGSize]()
  var layoutsByID = [TilingLayoutID: TilingLayoutState]()
  var dwindleAttempts = [TilingLayoutID: DwindleAttempt]()
  var pendingFocusedWindowID: CGWindowID?
  var membershipPollingTask: Task<Void, Never>?
  var unavailableFactWindowIDs = Set<CGWindowID>()
  var factRetryInterval = 1
  var factRetryCountdown = 1

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
    frameReconciler?.onFrameRefused = { [weak self] id, target, actual in
      self?.recordRefusedFrame(for: id, target: target, actual: actual)
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

  func layoutState(for spaceID: UInt64) -> TilingLayoutState? {
    layoutIDs(for: spaceID).first.flatMap { layoutsByID[$0] }
  }

  func isWindowTiled(_ windowID: CGWindowID) -> Bool {
    guard let layoutID = layoutIDByWindowID[windowID] else { return false }
    guard let state = layoutsByID[layoutID], state.selection != .float else { return false }
    return !floatingOverrideWindowIDs.contains(windowID)
      && !state.omittedWindowIDs.contains(windowID)
  }

  /// How the last reconcile treated a window, or `nil` when it was not part of it.
  func tilingStatus(for windowID: CGWindowID) -> WindowDisposition? {
    guard let disposition = dispositionByWindowID[windowID] else { return nil }
    guard disposition == .tiled else { return disposition }

    if floatingOverrideWindowIDs.contains(windowID) {
      return .floating(manualFloatingByWindowID[windowID] == true ? .manual : .rule)
    }
    guard let layoutID = layoutIDByWindowID[windowID], let state = layoutsByID[layoutID] else {
      return .pending
    }
    return state.selection == .float ? .floating(.floatLayout) : .tiled
  }

  func activeTree(of state: TilingLayoutState) -> TilingTree? {
    state.tree?.removing(hiddenWindowIDs(in: state))
  }

  func hiddenWindowIDs(in state: TilingLayoutState) -> Set<CGWindowID> {
    state.omittedWindowIDs.union(floatingOverrideWindowIDs)
  }

  func hiddenWindowIDs(inLayoutContaining windowID: CGWindowID) -> Set<CGWindowID> {
    layoutIDByWindowID[windowID].flatMap { layoutsByID[$0] }.map(hiddenWindowIDs(in:)) ?? []
  }

  func availableWindowIDs(in state: TilingLayoutState, floating: Bool) -> [CGWindowID] {
    (state.tree?.windowIDs ?? []).filter { windowID in
      guard !state.omittedWindowIDs.contains(windowID) else { return false }
      return state.selection == .float
        || floatingOverrideWindowIDs.contains(windowID) == floating
    }
  }

  func layoutIDs(for spaceID: UInt64) -> [TilingLayoutID] {
    layoutsByID.keys.filter { $0.spaceID == spaceID }.sorted()
  }
}

struct TilingReconciliationSnapshot {
  let windows: [TilingWindowSnapshot]

  let topology: SpaceTopology?
}
