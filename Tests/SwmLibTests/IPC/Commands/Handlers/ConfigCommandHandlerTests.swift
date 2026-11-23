import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("ConfigCommandHandler")
struct ConfigCommandHandlerTests {
  @Test("dispatch: selects layout geometry", arguments: LayoutSelection.allCases)
  func dispatchSelectsLayoutGeometry(selection: LayoutSelection) {
    let spaces = Spaces(activeSpaceID: nil)
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3), window(id: 4)],
      memberships: [1: [10], 2: [10], 3: [10], 4: [10]]
    )
    tiling.initialize()
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: tiling
    )
    let response = handler.dispatch(id: "request-id", command: .layout(scope: .global, selection))
    #expect(response.ok)
    #expect(response.message == selection.rawValue)
    if selection == .float {
      #expect(tiling.layoutPlan(for: layoutID(10)) == nil)
      return
    }
    guard let frames = tiling.layoutPlan(for: layoutID(10)) else {
      Issue.record("Expected layout frames")
      return
    }
    #expect(Set(frames.keys) == [1, 2, 3, 4])
    switch selection {
    case .master:
      #expect(frames[1] == CGRect(x: 0, y: 0, width: 500, height: 800))
      #expect(frames[4] == CGRect(x: 500, y: 533, width: 500, height: 267))
    case .monocle:
      #expect(frames.values.allSatisfy { $0 == CGRect(x: 0, y: 0, width: 1000, height: 800) })
    case .dwindle:
      #expect(frames[4] == CGRect(x: 750, y: 400, width: 250, height: 400))
    case .float:
      Issue.record("Unexpected layout")
    }
  }

  @Test("dispatch: gap updates defaults and overrides")
  func dispatchGapUpdatesDefaultsAndOverrides() {
    let spaces = Spaces(activeSpaceID: nil)
    spaces.setGap(5, for: 1)
    let handler = handler(spaces: spaces)

    let response = handler.dispatch(id: "request-id", command: .gap(scope: .global, .absolute(12)))

    #expect(response.ok)
    #expect(spaces.settings(for: 1).gap == 12)
    #expect(spaces.settings(for: 2).gap == 12)
  }

  @Test("dispatch: adjusts global gap, padding, and master ratio and applies them to every Space")
  func dispatchAdjustsGlobalGapPaddingAndMasterRatioAndAppliesThemToEverySpace() {
    let spaces = Spaces(activeSpaceID: nil)
    let handler = handler(spaces: spaces)
    #expect(handler.dispatch(id: "request-id", command: .gap(scope: .global, .absolute(6))).ok)
    #expect(
      handler.dispatch(
        id: "request-id",
        command: .padding(
          scope: .global,
          [
            PaddingSideChange(side: .top, change: .absolute(8)),
            PaddingSideChange(side: .left, change: .absolute(4)),
          ]
        )
      ).ok
    )
    spaces.setGap(20, for: 1)
    spaces.setPadding(SpacePadding(top: 30, bottom: 2, left: 30, right: 4), for: 1)

    #expect(handler.dispatch(id: "request-id", command: .gap(scope: .global, .relative(2))).ok)
    #expect(
      handler.dispatch(
        id: "request-id",
        command: .padding(scope: .global, [PaddingSideChange(side: .top, change: .relative(-10))])
      ).ok
    )
    #expect(
      handler.dispatch(id: "request-id", command: .masterRatio(scope: .global, .relative(0.1))).ok
    )

    #expect(spaces.settings(for: 1).gap == 8)
    #expect(spaces.settings(for: 1).padding == SpacePadding(top: 0, bottom: 2, left: 30, right: 4))
    #expect(spaces.settings(for: 2).padding == SpacePadding(top: 0, bottom: 0, left: 4, right: 0))
    #expect(handler.dispatch(id: "request-id", command: .gap(scope: .global, nil)).message == "8")
    #expect(
      handler.dispatch(id: "request-id", command: .masterRatio(scope: .global, nil)).message
        == "0.6"
    )

    #expect(
      handler.dispatch(id: "request-id", command: .gap(scope: .global, .absolute(Int.max))).ok
    )
    let overflow = handler.dispatch(id: "request-id", command: .gap(scope: .global, .relative(1)))
    #expect(overflow.message == "config gap adjustment overflows integer range")
    #expect(spaces.settings(for: 1).gap == Int.max)
  }

  @Test("dispatch: applies master controls and split preservation to geometry")
  func dispatchAppliesMasterControlsAndSplitPreservationToGeometry() {
    let spaces = Spaces(activeSpaceID: nil)
    var bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let tiling = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: [window(id: 1), window(id: 2)],
          topology: SpaceTopology(
            spacesByID: [10: SpaceTopologyDescriptor(id: 10, displayID: "display", type: .normal)],
            visibleSpaceIDByDisplayID: ["display": 10],
            spaceIDsByWindowID: [1: [10], 2: [10]],
            displaysByID: ["display": SpaceTopologyDisplay(visibleFrame: bounds)]
          )
        )
      },
      spaces: spaces
    )
    tiling.initialize()
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: tiling
    )
    #expect(handler.dispatch(id: "request-id", command: .layout(scope: .global, .master)).ok)
    #expect(
      handler.dispatch(id: "request-id", command: .masterRatio(scope: .global, .absolute(0.65))).ok
    )
    #expect(
      handler.dispatch(id: "request-id", command: .masterPlacement(scope: .global, .set(.right))).ok
    )
    let cycled = handler.dispatch(
      id: "request-id",
      command: .masterPlacement(scope: .global, .cycle(.prev))
    )
    #expect(cycled.ok && cycled.message == "top")
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == [
          1: CGRect(x: 0, y: 0, width: 1000, height: 520),
          2: CGRect(x: 0, y: 520, width: 1000, height: 280),
        ]
    )
    #expect(handler.dispatch(id: "request-id", command: .preserveSplit(scope: .global, true)).ok)
    #expect(handler.dispatch(id: "request-id", command: .layout(scope: .global, .dwindle)).ok)
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == [
          1: CGRect(x: 0, y: 0, width: 500, height: 800),
          2: CGRect(x: 500, y: 0, width: 500, height: 800),
        ]
    )
    bounds.size.width = 400
    tiling.reconcile()
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == [
          1: CGRect(x: 0, y: 0, width: 200, height: 800),
          2: CGRect(x: 200, y: 0, width: 200, height: 800),
        ]
    )
  }

  @Test("dispatch: selects focus follows mouse mode")
  func dispatchSelectsFocusFollowsMouseMode() {
    let handler = handler(spaces: Spaces(activeSpaceID: nil))

    let autofocus = handler.dispatch(id: "request-id", command: .focusFollowsMouse(.autofocus))
    let autoraise = handler.dispatch(id: "request-id", command: .focusFollowsMouse(.autoraise))
    let disabled = handler.dispatch(id: "request-id", command: .focusFollowsMouse(.off))

    #expect(autofocus.ok && autofocus.message == "autofocus")
    #expect(autoraise.ok && autoraise.message == "autoraise")
    #expect(disabled.ok && disabled.message == "off")
  }

  @Test("dispatch: padding updates defaults and preserves other override sides")
  func dispatchPaddingUpdatesDefaultsAndPreservesOtherOverrideSides() {
    let spaces = Spaces(activeSpaceID: nil)
    spaces.setPadding(SpacePadding(top: 1, bottom: 2, left: 3, right: 4), for: 1)
    let handler = handler(spaces: spaces)

    let response = handler.dispatch(
      id: "request-id",
      command: .padding(
        scope: .global,
        [
          PaddingSideChange(side: .top, change: .absolute(10)),
          PaddingSideChange(side: .right, change: .absolute(-5)),
        ]
      )
    )

    #expect(response.ok)
    #expect(spaces.settings(for: 1).padding == SpacePadding(top: 10, bottom: 2, left: 3, right: 0))
    #expect(spaces.settings(for: 2).padding == SpacePadding(top: 10, bottom: 0, left: 0, right: 0))
  }

  @Test(
    "dispatch: rejects out-of-range ratios in global and Space scopes",
    arguments: [ConfigScope.global, .currentSpace]
  )
  func dispatchRejectsOutOfRangeRatiosInGlobalAndSpaceScopes(scope: ConfigScope) {
    let handler = handler(spaces: Spaces(activeSpaceID: 42))
    let cases: [(IPCCommand.Config, String)] = [
      (.masterRatio(scope: scope, .absolute(0.05)), "master-ratio must be between 0.1 and 0.9"),
      (.masterRatio(scope: scope, .absolute(5)), "master-ratio must be between 0.1 and 0.9"),
      (.splitRatio(scope: scope, .absolute(0.95)), "split-ratio must be between 0.1 and 0.9"),
    ]
    for (command, message) in cases {
      let response = handler.dispatch(id: "request-id", command: command)
      #expect(!response.ok)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == message)
    }
  }

  @Test("dispatch: applies animation duration and preserves it after invalid requests")
  func dispatchAppliesAnimationDurationAndPreservesItAfterInvalidRequests() {
    let spaces = Spaces(activeSpaceID: nil)
    let reconciler = makeTestReconciler(AnimationTestApp(processID: 1))
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: makeTiling(frameReconciler: reconciler)
    )
    for duration in [0.0, 0.18, 1.0] {
      #expect(handler.dispatch(id: "request-id", command: .animationDuration(duration)).ok)
      #expect(reconciler.animationDuration == duration)
    }
    for invalid in [-1.0, 1.1, .nan, .infinity] {
      let response = handler.dispatch(id: "request-id", command: .animationDuration(invalid))
      #expect(!response.ok)
      #expect(response.errorCode == .invalidRequest)
      #expect(reconciler.animationDuration == 1)
    }
  }

  @Test("dispatch: validates and applies animation easing")
  func dispatchValidatesAndAppliesAnimationEasing() {
    let spaces = Spaces(activeSpaceID: nil)
    let reconciler = makeTestReconciler(AnimationTestApp(processID: 1))
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: makeTiling(frameReconciler: reconciler)
    )
    for easing in AnimationEasing.allCases {
      let response = handler.dispatch(id: "request-id", command: .animationEasing(easing))
      #expect(response.ok)
      #expect(reconciler.animationEasing == easing)
    }
  }

  @Test("dispatch: reports current values for settings given without a value")
  func dispatchReportsCurrentValuesForSettingsGivenWithoutAValue() {
    let handler = handler(spaces: Spaces(activeSpaceID: nil))
    let mutations: [IPCCommand.Config] = [
      .gap(scope: .global, .absolute(6)),
      .padding(scope: .global, [PaddingSideChange(side: .top, change: .absolute(8))]),
      .layout(scope: .global, .dwindle),
      .masterRatio(scope: .global, .absolute(0.6)),
      .splitRatio(scope: .global, .absolute(0.4)),
      .preserveSplit(scope: .global, true),
    ]
    for command in mutations {
      #expect(handler.dispatch(id: "request-id", command: command).ok)
    }

    let queries: [(IPCCommand.Config, String)] = [
      (.gap(scope: .global, nil), "6"),
      (.padding(scope: .global, []), "--top 8 --bottom 0 --left 0 --right 0"),
      (.layout(scope: .global, nil), "dwindle"),
      (.masterRatio(scope: .global, nil), "0.6"),
      (.splitRatio(scope: .global, nil), "0.4"),
      (.preserveSplit(scope: .global, nil), "on"),
      (.masterPlacement(scope: .global, nil), "left"),
      (.focusFollowsMouse(nil), "off"),
      (.animationDuration(nil), "0.0"),
      (.animationEasing(nil), "ease-out-quad"),
    ]
    for (command, value) in queries {
      let response = handler.dispatch(id: "request-id", command: command)
      #expect(response.ok && response.message == value)
    }
  }

  @Test("dispatch: applies absolute and relative padding with clamping to the active Space")
  func dispatchAppliesAbsoluteAndRelativePaddingWithClampingToTheActiveSpace() {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = handler(spaces: spaces)
    let all20 = PaddingSide.allCases.map { PaddingSideChange(side: $0, change: .absolute(20)) }
    #expect(handler.dispatch(id: "request-id", command: .padding(scope: .currentSpace, all20)).ok)
    #expect(
      handler.dispatch(
        id: "request-id",
        command: .padding(
          scope: .currentSpace,
          [
            PaddingSideChange(side: .top, change: .relative(10)),
            PaddingSideChange(side: .left, change: .relative(-5)),
          ]
        )
      ).ok
    )
    #expect(
      spaces.settings(for: 42).padding == SpacePadding(top: 30, bottom: 20, left: 15, right: 20)
    )
    #expect(
      handler.dispatch(
        id: "request-id",
        command: .padding(
          scope: .currentSpace,
          [
            PaddingSideChange(side: .top, change: .absolute(-1)),
            PaddingSideChange(side: .left, change: .relative(2)),
          ]
        )
      ).ok
    )
    #expect(
      spaces.settings(for: 42).padding == SpacePadding(top: 0, bottom: 20, left: 17, right: 20)
    )
    let allMinus30 = PaddingSide.allCases.map {
      PaddingSideChange(side: $0, change: .relative(-30))
    }
    #expect(
      handler.dispatch(id: "request-id", command: .padding(scope: .currentSpace, allMinus30)).ok
    )
    #expect(spaces.settings(for: 42).padding == .zero)
    #expect(spaces.settings(for: 43) == .defaults)
  }

  @Test("dispatch: applies absolute and relative gaps only to the active Space")
  func dispatchAppliesAbsoluteAndRelativeGapsOnlyToTheActiveSpace() {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = handler(spaces: spaces)
    #expect(
      handler.dispatch(id: "request-id", command: .gap(scope: .currentSpace, .absolute(0))).ok)
    let relative = handler.dispatch(
      id: "request-id",
      command: .gap(scope: .currentSpace, .relative(10))
    )
    #expect(relative.ok && relative.message.isEmpty)
    #expect(spaces.settings(for: 42).gap == 10)
    #expect(
      handler.dispatch(id: "request-id", command: .gap(scope: .currentSpace, .absolute(-1))).ok
    )
    #expect(spaces.settings(for: 42).gap == 0)
    #expect(
      handler.dispatch(id: "request-id", command: .gap(scope: .currentSpace, .relative(-10))).ok
    )
    #expect(spaces.settings(for: 42).gap == 0)
    #expect(spaces.settings(for: 43) == .defaults)
  }

  @Test("dispatch: updates Space layout controls")
  func dispatchUpdatesSpaceLayoutControls() {
    let spaces = Spaces(activeSpaceID: 42)
    var bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let tiling = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: [window(id: 1), window(id: 2)],
          topology: SpaceTopology(
            spacesByID: [42: SpaceTopologyDescriptor(id: 42, displayID: "display", type: .normal)],
            visibleSpaceIDByDisplayID: ["display": 42],
            spaceIDsByWindowID: [1: [42], 2: [42]],
            displaysByID: ["display": SpaceTopologyDisplay(visibleFrame: bounds)]
          )
        )
      },
      spaces: spaces
    )
    tiling.initialize()
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: tiling
    )

    let ratio = handler.dispatch(
      id: "request-id",
      command: .masterRatio(scope: .currentSpace, .absolute(0.6))
    )
    let relativeRatio = handler.dispatch(
      id: "request-id",
      command: .masterRatio(scope: .currentSpace, .relative(0.1))
    )
    let placement = handler.dispatch(
      id: "request-id",
      command: .masterPlacement(scope: .currentSpace, .set(.bottom))
    )
    let cycledPlacement = handler.dispatch(
      id: "request-id",
      command: .masterPlacement(scope: .currentSpace, .cycle(.next))
    )
    let preserve = handler.dispatch(
      id: "request-id",
      command: .preserveSplit(scope: .currentSpace, true)
    )
    let layout = handler.dispatch(id: "request-id", command: .layout(scope: .currentSpace, .master))

    #expect(ratio.ok)
    #expect(relativeRatio.ok)
    #expect(placement.ok && placement.message == "bottom")
    #expect(cycledPlacement.ok && cycledPlacement.message == "left")
    #expect(preserve.ok && preserve.message == "on")
    #expect(layout.ok)
    #expect(
      tiling.layoutPlan(for: layoutID(42))
        == [
          1: CGRect(x: 0, y: 0, width: 700, height: 800),
          2: CGRect(x: 700, y: 0, width: 300, height: 800),
        ]
    )

    #expect(
      handler.dispatch(id: "request-id", command: .layout(scope: .currentSpace, .monocle)).message
        == "monocle"
    )
    #expect(tiling.layoutPlan(for: layoutID(42)) == [1: bounds, 2: bounds])
    #expect(
      handler.dispatch(id: "request-id", command: .layout(scope: .currentSpace, .float)).message
        == "float"
    )
    #expect(tiling.layoutPlan(for: layoutID(42)) == nil)
    #expect(
      handler.dispatch(id: "request-id", command: .layout(scope: .currentSpace, .dwindle)).message
        == "dwindle"
    )
    bounds.size.width = 400
    tiling.reconcile()
    #expect(
      tiling.layoutPlan(for: layoutID(42))
        == [
          1: CGRect(x: 0, y: 0, width: 200, height: 800),
          2: CGRect(x: 200, y: 0, width: 200, height: 800),
        ]
    )
  }

  @Test("dispatch: rebalances dwindle splits and uses the ratio for new splits")
  func dispatchRebalancesDwindleSplitsAndUsesTheRatioForNewSplits() {
    let spaces = Spaces(activeSpaceID: 42)
    var windowIDs: [CGWindowID] = [1, 2]
    let tiling = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: windowIDs.map { window(id: $0) },
          topology: SpaceTopology(
            spacesByID: [42: SpaceTopologyDescriptor(id: 42, displayID: "display", type: .normal)],
            visibleSpaceIDByDisplayID: ["display": 42],
            spaceIDsByWindowID: Dictionary(uniqueKeysWithValues: windowIDs.map { ($0, [42]) }),
            displaysByID: [
              "display": SpaceTopologyDisplay(
                visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800)
              )
            ]
          )
        )
      },
      spaces: spaces
    )
    tiling.initialize()
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: tiling
    )
    #expect(handler.dispatch(id: "request-id", command: .layout(scope: .currentSpace, .dwindle)).ok)

    #expect(
      handler.dispatch(id: "request-id", command: .splitRatio(scope: .currentSpace, .absolute(0.6)))
        .ok
    )
    #expect(
      tiling.layoutPlan(for: layoutID(42))
        == [
          1: CGRect(x: 0, y: 0, width: 600, height: 800),
          2: CGRect(x: 600, y: 0, width: 400, height: 800),
        ]
    )

    #expect(
      handler.dispatch(
        id: "request-id",
        command: .splitRatio(scope: .currentSpace, .relative(-0.2))
      ).ok
    )
    windowIDs.append(3)
    tiling.reconcile()
    #expect(
      tiling.layoutPlan(for: layoutID(42))
        == [
          1: CGRect(x: 0, y: 0, width: 400, height: 800),
          2: CGRect(x: 400, y: 0, width: 600, height: 320),
          3: CGRect(x: 400, y: 320, width: 600, height: 480),
        ]
    )
  }

  @Test("dispatch: reports the selected Space's values for settings given without a value")
  func dispatchReportsTheSelectedSpacesValuesForSettingsGivenWithoutAValue() {
    let spaces = Spaces(activeSpaceID: 10)
    let tiling = makeTiling()
    tiling.initialize()
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: tiling,
      spaceIDProvider: { [10, 11] }
    )
    let mutations: [IPCCommand.Config] = [
      .gap(scope: .currentSpace, .absolute(6)),
      .padding(scope: .currentSpace, [PaddingSideChange(side: .top, change: .absolute(8))]),
      .layout(scope: .currentSpace, .dwindle),
      .masterRatio(scope: .currentSpace, .absolute(0.6)),
      .masterPlacement(scope: .currentSpace, .set(.top)),
      .splitRatio(scope: .currentSpace, .absolute(0.4)),
      .preserveSplit(scope: .currentSpace, true),
    ]
    for command in mutations {
      #expect(handler.dispatch(id: "request-id", command: command).ok)
    }

    let queries: [(IPCCommand.Config, String)] = [
      (.gap(scope: .currentSpace, nil), "6"),
      (.padding(scope: .currentSpace, []), "--top 8 --bottom 0 --left 0 --right 0"),
      (.layout(scope: .currentSpace, nil), "dwindle"),
      (.masterRatio(scope: .currentSpace, nil), "0.6"),
      (.masterPlacement(scope: .currentSpace, nil), "top"),
      (.splitRatio(scope: .currentSpace, nil), "0.4"),
      (.preserveSplit(scope: .currentSpace, nil), "on"),
    ]
    for (command, value) in queries {
      let response = handler.dispatch(id: "request-id", command: command)
      #expect(response.ok && response.message == value)
    }
    let other = handler.dispatch(id: "request-id", command: .gap(scope: .space(2), nil))
    #expect(other.ok && other.message == "0")
  }

  @Test(
    "dispatch: rejects Space overflow without changing settings",
    arguments: [
      (IPCCommand.Config.gap(scope: .currentSpace, .relative(1)), "gap", false),
      (.gap(scope: .currentSpace, .relative(1)), "gap", true),
      (
        .padding(scope: .currentSpace, [PaddingSideChange(side: .top, change: .relative(1))]),
        "padding", true
      ),
      (
        .padding(scope: .currentSpace, [PaddingSideChange(side: .bottom, change: .relative(1))]),
        "padding", true
      ),
      (
        .padding(scope: .currentSpace, [PaddingSideChange(side: .left, change: .relative(1))]),
        "padding", true
      ),
      (
        .padding(scope: .currentSpace, [PaddingSideChange(side: .right, change: .relative(1))]),
        "padding", true
      ),
    ]
  )
  func dispatchRejectsSpaceOverflowWithoutChangingSettings(
    command: IPCCommand.Config,
    setting: String,
    existingOverride: Bool
  ) {
    let spaces = Spaces(activeSpaceID: 42)
    spaces.updateAllSettings { settings in
      settings.gap = Int.max
      settings.padding = SpacePadding(top: Int.max, bottom: Int.max, left: Int.max, right: Int.max)
    }
    if existingOverride { spaces.setGap(Int.max, for: 42) }
    let handler = handler(spaces: spaces)
    let previous = spaces.settings(for: 42)
    let response = handler.dispatch(id: "request-id", command: command)
    #expect(!response.ok)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "space \(setting) adjustment overflows integer range")
    #expect(spaces.settings(for: 42) == previous)
    #expect(spaces.settings(for: 43) == previous)
  }

  @Test("dispatch: accepts integer extremes without overflowing intermediate adjustments")
  func dispatchAcceptsIntegerExtremesWithoutOverflowingIntermediateAdjustments() {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = handler(spaces: spaces)
    #expect(
      handler.dispatch(
        id: "request-id",
        command: .padding(
          scope: .currentSpace,
          PaddingSide.allCases.map { PaddingSideChange(side: $0, change: .absolute(Int.max)) }
        )
      ).ok
    )
    #expect(
      handler.dispatch(
        id: "request-id",
        command: .padding(
          scope: .currentSpace,
          [
            PaddingSideChange(side: .top, change: .relative(Int.min)),
            PaddingSideChange(side: .bottom, change: .relative(-1)),
            PaddingSideChange(side: .left, change: .relative(0)),
            PaddingSideChange(side: .right, change: .relative(-Int.max)),
          ]
        )
      ).ok
    )
    #expect(
      spaces.settings(for: 42).padding
        == SpacePadding(top: 0, bottom: Int.max - 1, left: Int.max, right: 0)
    )
    #expect(
      handler.dispatch(id: "request-id", command: .gap(scope: .currentSpace, .absolute(Int.max))).ok
    )
    #expect(
      handler.dispatch(id: "request-id", command: .gap(scope: .currentSpace, .relative(Int.min))).ok
    )
    #expect(spaces.settings(for: 42).gap == 0)
    #expect(
      handler.dispatch(id: "request-id", command: .gap(scope: .currentSpace, .relative(Int.max))).ok
    )
    #expect(spaces.settings(for: 42).gap == Int.max)
    #expect(spaces.settings(for: 43) == .defaults)
  }

  @Test("dispatch: updates a selected space by index")
  func dispatchUpdatesASelectedSpaceByIndex() {
    let spaces = Spaces(activeSpaceID: 1)
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces),
      spaceIDProvider: { [1, 2] }
    )

    let response = handler.dispatch(
      id: "request-id", command: .gap(scope: .space(2), .absolute(10)))

    #expect(response.ok)
    #expect(spaces.settings(for: 1).gap == 0)
    #expect(spaces.settings(for: 2).gap == 10)
  }

  @Test("dispatch: rejects invalid space indexes")
  func dispatchRejectsInvalidSpaceIndexes() {
    let spaces = Spaces(activeSpaceID: 1)
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces),
      spaceIDProvider: { [1, 2] }
    )

    let nonPositive = handler.dispatch(
      id: "request-id",
      command: .gap(scope: .space(0), .absolute(10))
    )
    let outOfRange = handler.dispatch(
      id: "request-id",
      command: .gap(scope: .space(3), .absolute(10))
    )

    #expect(nonPositive.errorCode == .invalidRequest)
    #expect(outOfRange.errorCode == .invalidRequest)
    #expect(outOfRange.message == "space index out of range: 3")
  }

  @Test("dispatch: rejects active-space mutation without active space")
  func dispatchRejectsActiveSpaceMutationWithoutActiveSpace() {
    let handler = handler(spaces: Spaces(activeSpaceID: nil))
    let response = handler.dispatch(
      id: "request-id",
      command: .gap(scope: .currentSpace, .absolute(10))
    )

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "no active space")
  }

  @Test("dispatch: rejects current-Space commands until the active Space can be read again")
  func dispatchRejectsCurrentSpaceCommandsUntilTheActiveSpaceCanBeReadAgain() {
    var readActiveSpaceID: UInt64?
    let spaces = Spaces(activeSpaceID: 11, activeSpaceProvider: { readActiveSpaceID })
    let tiling = makeTestTiling(
      spaces: spaces,
      windows: [window(id: 1)],
      topology: SpaceTopology(
        spacesByID: [11: SpaceTopologyDescriptor(id: 11, displayID: "display", type: .normal)],
        visibleSpaceIDByDisplayID: ["display": 11],
        spaceIDsByWindowID: [1: [11]],
        displaysByID: [
          "display": SpaceTopologyDisplay(
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
          )
        ]
      )
    )
    tiling.initialize()
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: tiling
    )
    spaces.activeSpaceBecameUnavailable()

    let gap = handler.dispatch(id: "request-id", command: .gap(scope: .currentSpace, .absolute(10)))
    let layout = handler.dispatch(
      id: "request-id",
      command: .layout(scope: .currentSpace, .master)
    )

    for response in [gap, layout] {
      #expect(!response.ok)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "no active space")
    }
    #expect(spaces.settings(for: 11).gap == SpaceSettings.defaults.gap)
    #expect(tiling.layoutState(for: 11)?.selection == .float)

    readActiveSpaceID = 11
    #expect(
      handler.dispatch(id: "request-id", command: .gap(scope: .currentSpace, .absolute(10))).ok
    )
    #expect(handler.dispatch(id: "request-id", command: .layout(scope: .currentSpace, .master)).ok)
    #expect(spaces.settings(for: 11).gap == 10)
    #expect(tiling.layoutState(for: 11)?.selection == .master)
    #expect(spaces.currentActiveSpaceID == 11)
  }

  private func layoutID(_ spaceID: UInt64) -> TilingLayoutID {
    TilingLayoutID(spaceID: spaceID, displayID: "display")
  }

  private func handler(spaces: Spaces) -> ConfigCommandHandler {
    ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces)
    )
  }
}
