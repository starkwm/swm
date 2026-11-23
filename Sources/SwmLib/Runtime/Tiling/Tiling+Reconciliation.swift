import CoreGraphics

extension Tiling {
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
    minimumSizeByWindowID = minimumSizeByWindowID.filter { liveIDs.contains($0.key) }
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
    dispositionByWindowID.removeAll(keepingCapacity: true)

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
      dispositionByWindowID[window.id] =
        disposition == .tiled && window.isMinimized ? .excluded(.minimized) : disposition
      let placement: (layoutID: TilingLayoutID, isOmitted: Bool)

      switch disposition {
      case .floating(.notResizable), .floating(.dialog):
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

  func updateMembershipPolling() {
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
}
