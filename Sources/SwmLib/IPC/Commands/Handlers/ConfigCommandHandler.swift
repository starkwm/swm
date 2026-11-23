@MainActor
struct ConfigCommandHandler {
  private let windows: Windows
  private let spaces: Spaces
  private let tiling: Tiling
  private let spaceIDProvider: () -> [UInt64]

  init(
    windows: Windows,
    spaces: Spaces,
    tiling: Tiling,
    spaceIDProvider: @escaping () -> [UInt64] = {
      WindowServerClient.shared.allSpaceIDs()
    }
  ) {
    self.windows = windows
    self.spaces = spaces
    self.tiling = tiling
    self.spaceIDProvider = spaceIDProvider
  }

  func dispatch(id: String, command: IPCCommand.Config) -> IPCResponse {
    IPCCommandError.catching(id: id) {
      switch command {
      case .animationDuration(let duration):
        guard let duration else {
          return .success(id: id, message: String(tiling.animationDuration))
        }
        guard duration.isFinite, (0...1).contains(duration) else {
          throw IPCCommandError.invalidRequest("animation-duration must be between 0 and 1 seconds")
        }
        tiling.setAnimationDuration(duration)
        return .acknowledged(id: id)

      case .animationEasing(let easing):
        guard let easing else {
          return .success(id: id, message: tiling.animationEasing.rawValue)
        }
        tiling.setAnimationEasing(easing)
        return .success(id: id, message: easing.rawValue)

      case .focusFollowsMouse(let mode):
        guard let mode else {
          return .success(id: id, message: windows.focusFollowsMouseMode.rawValue)
        }
        windows.setFocusFollowsMouseMode(mode)
        return .success(id: id, message: mode.rawValue)

      case .layout(let scope, let selection):
        return try layout(id: id, scope: scope, selection: selection)

      case .masterRatio(let scope, let change):
        return try masterRatio(id: id, scope: scope, change: change)

      case .masterPlacement(let scope, let change):
        return try masterPlacement(id: id, scope: scope, change: change)

      case .splitRatio(let scope, let change):
        return try splitRatio(id: id, scope: scope, change: change)

      case .preserveSplit(let scope, let enabled):
        return try preserveSplit(id: id, scope: scope, enabled: enabled)

      case .gap(let scope, let change):
        return try gap(id: id, scope: scope, change: change)

      case .padding(let scope, let changes):
        return try padding(id: id, scope: scope, changes: changes)
      }
    }
  }

  private func layout(
    id: String,
    scope: ConfigScope,
    selection: LayoutSelection?
  ) throws -> IPCResponse {
    guard let spaceID = try resolveSpaceID(for: scope) else {
      guard let selection else {
        return .success(id: id, message: tiling.defaultState.selection.rawValue)
      }
      tiling.setLayoutForSpaces(selection)
      return .success(id: id, message: selection.rawValue)
    }

    guard let selection else {
      return .success(id: id, message: try layoutState(for: spaceID).selection.rawValue)
    }
    guard tiling.setLayout(selection, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return .success(id: id, message: selection.rawValue)
  }

  private func masterRatio(
    id: String,
    scope: ConfigScope,
    change: LayoutRatioChange?
  ) throws -> IPCResponse {
    if let change {
      try validateRatio(change, setting: "master-ratio")
    }
    guard let spaceID = try resolveSpaceID(for: scope) else {
      guard let change else {
        return .success(id: id, message: String(Double(tiling.defaultState.masterRatio)))
      }
      tiling.changeMasterRatioForAllSpaces(change)
      return .acknowledged(id: id)
    }

    guard let change else {
      return .success(id: id, message: String(Double(try layoutState(for: spaceID).masterRatio)))
    }
    guard tiling.changeMasterRatio(change, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return .acknowledged(id: id)
  }

  private func masterPlacement(
    id: String,
    scope: ConfigScope,
    change: MasterPlacementChange?
  ) throws -> IPCResponse {
    guard let spaceID = try resolveSpaceID(for: scope) else {
      guard let change else {
        return .success(id: id, message: tiling.defaultState.masterPlacement.rawValue)
      }
      let placement =
        switch change {
        case .set(let placement): placement
        case .cycle(let direction): tiling.defaultState.masterPlacement.cycled(in: direction)
        }
      tiling.setMasterPlacementForAllSpaces(placement)
      return .success(id: id, message: placement.rawValue)
    }

    guard let change else {
      return .success(id: id, message: try layoutState(for: spaceID).masterPlacement.rawValue)
    }
    let placement: MasterPlacement?
    switch change {
    case .set(let selectedPlacement):
      placement =
        tiling.setMasterPlacement(selectedPlacement, for: spaceID) ? selectedPlacement : nil
    case .cycle(let direction):
      placement = tiling.cycleMasterPlacement(direction, for: spaceID)
    }
    guard let placement else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return .success(id: id, message: placement.rawValue)
  }

  private func splitRatio(
    id: String,
    scope: ConfigScope,
    change: LayoutRatioChange?
  ) throws -> IPCResponse {
    if let change {
      try validateRatio(change, setting: "split-ratio")
    }
    guard let spaceID = try resolveSpaceID(for: scope) else {
      guard let change else {
        return .success(id: id, message: String(Double(tiling.defaultState.splitRatio)))
      }
      tiling.changeSplitRatioForAllSpaces(change)
      return .acknowledged(id: id)
    }

    guard let change else {
      return .success(id: id, message: String(Double(try layoutState(for: spaceID).splitRatio)))
    }
    guard tiling.changeSplitRatio(change, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return .acknowledged(id: id)
  }

  private func preserveSplit(
    id: String,
    scope: ConfigScope,
    enabled: Bool?
  ) throws -> IPCResponse {
    guard let spaceID = try resolveSpaceID(for: scope) else {
      guard let enabled else {
        return .success(id: id, message: tiling.defaultState.preserveSplitDirections ? "on" : "off")
      }
      tiling.setSplitDirectionPreservationForAllSpaces(enabled)
      return .success(id: id, message: enabled ? "on" : "off")
    }

    guard let enabled else {
      let state = try layoutState(for: spaceID)
      return .success(id: id, message: state.preserveSplitDirections ? "on" : "off")
    }
    guard tiling.setSplitDirectionPreservation(enabled, for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return .success(id: id, message: enabled ? "on" : "off")
  }

  private func gap(
    id: String,
    scope: ConfigScope,
    change: NumericChange<Int>?
  ) throws -> IPCResponse {
    guard let spaceID = try resolveSpaceID(for: scope) else {
      guard let change else {
        return .success(id: id, message: String(spaces.defaultSettings.gap))
      }
      let gap = try change.applying(to: spaces.defaultSettings.gap, context: "config gap")
      spaces.updateAllSettings { settings in
        settings.gap = max(0, gap)
      }
      tiling.reflowVisibleSpaces()
      return .acknowledged(id: id)
    }

    guard let change else {
      return .success(id: id, message: String(spaces.settings(for: spaceID).gap))
    }
    let gap = try change.applying(to: spaces.settings(for: spaceID).gap, context: "space gap")
    spaces.setGap(gap, for: spaceID)
    tiling.reflow(spaceID: spaceID)
    return .acknowledged(id: id)
  }

  private func padding(
    id: String,
    scope: ConfigScope,
    changes: [PaddingSideChange]
  ) throws -> IPCResponse {
    guard let spaceID = try resolveSpaceID(for: scope) else {
      guard !changes.isEmpty else {
        return .success(id: id, message: spaces.defaultSettings.padding.commandOptions)
      }
      let padding = try PaddingSideChange.applying(
        changes,
        to: spaces.defaultSettings.padding,
        context: "config padding"
      )
      spaces.updateAllSettings { settings in
        for change in changes {
          settings.padding[change.side] = padding[change.side]
        }
      }
      tiling.reflowVisibleSpaces()
      return .acknowledged(id: id)
    }

    guard !changes.isEmpty else {
      return .success(id: id, message: spaces.settings(for: spaceID).padding.commandOptions)
    }
    let padding = try PaddingSideChange.applying(
      changes,
      to: spaces.settings(for: spaceID).padding,
      context: "space padding"
    )
    spaces.setPadding(padding, for: spaceID)
    tiling.reflow(spaceID: spaceID)
    return .acknowledged(id: id)
  }

  private func resolveSpaceID(for scope: ConfigScope) throws -> UInt64? {
    switch scope {
    case .global:
      return nil
    case .currentSpace:
      guard let id = spaces.resolveActiveSpaceID() else {
        throw IPCCommandError.invalidRequest("no active space")
      }
      return id
    case .space(let index):
      guard index > 0 else {
        throw IPCCommandError.invalidRequest("invalid space index")
      }
      let spaceIDs = spaceIDProvider()
      guard spaceIDs.indices.contains(index - 1) else {
        throw IPCCommandError.invalidRequest("space index out of range: \(index)")
      }
      return spaceIDs[index - 1]
    }
  }

  private func layoutState(for spaceID: UInt64) throws -> TilingLayoutState {
    guard let state = tiling.layoutState(for: spaceID) else {
      throw IPCCommandError.invalidRequest("automatic tiling unavailable for selected space")
    }
    return state
  }

  private func validateRatio(_ change: LayoutRatioChange, setting: String) throws {
    if case .absolute(let ratio) = change, !TilingLimits.ratioRange.contains(ratio) {
      throw IPCCommandError.invalidRequest("\(setting) must be between 0.1 and 0.9")
    }
  }
}
