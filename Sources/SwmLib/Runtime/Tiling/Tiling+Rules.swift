import CoreGraphics

extension Tiling {
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

  func applyRulePlacements(
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
}
