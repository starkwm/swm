import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("ConfigCommandHandler")
struct ConfigCommandHandlerTests {
  @Test("dispatch selects layout geometry", arguments: ["master", "monocle", "dwindle", "float"])
  func dispatchSelectsLayoutGeometry(selection: String) {
    let spaces = Spaces(activeSpaceID: nil)
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3), window(id: 4)],
      memberships: [1: [10], 2: [10], 3: [10], 4: [10]]
    )
    tiling.initialize()
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace()),
      spaces: spaces,
      tiling: tiling
    )
    let response = handler.dispatch(request(command: "layout", args: [selection]))
    #expect(response.ok)
    #expect(response.message == selection)
    if selection == "float" {
      #expect(tiling.layoutPlan(for: layoutID(10)) == .disabled)
      return
    }
    guard case .layout(.frames(let frames)) = tiling.layoutPlan(for: layoutID(10)) else {
      Issue.record("Expected layout frames")
      return
    }
    #expect(Set(frames.keys) == [1, 2, 3, 4])
    switch selection {
    case "master":
      #expect(frames[1] == CGRect(x: 0, y: 0, width: 500, height: 800))
      #expect(frames[4] == CGRect(x: 500, y: 533, width: 500, height: 267))
    case "monocle":
      #expect(frames.values.allSatisfy { $0 == CGRect(x: 0, y: 0, width: 1000, height: 800) })
    case "dwindle":
      #expect(frames[4] == CGRect(x: 750, y: 400, width: 250, height: 400))
    default: Issue.record("Unexpected layout")
    }
  }

  @Test("dispatch: window gap updates defaults and overrides")
  func dispatchWindowGapUpdatesDefaultsAndOverrides() {
    let spaces = Spaces(activeSpaceID: nil)
    spaces.setGap(5, for: 1)
    let handler = handler(spaces: spaces)

    let response = handler.dispatch(request(command: "window-gap", args: ["12"]))

    #expect(response.ok)
    #expect(spaces.settings(for: 1).gap == 12)
    #expect(spaces.settings(for: 2).gap == 12)
  }

  @Test("dispatch: accepts layout controls")
  func dispatchAcceptsLayoutControls() {
    let handler = handler(spaces: Spaces(activeSpaceID: nil))

    let ratio = handler.dispatch(request(command: "master-ratio", args: ["0.65"]))
    let placement = handler.dispatch(request(command: "master-placement", args: ["top"]))
    let preserve = handler.dispatch(request(command: "preserve-split", args: ["true"]))

    #expect(ratio.ok)
    #expect(placement.ok && placement.message == "top")
    #expect(preserve.ok && preserve.message == "on")
  }

  @Test("dispatch: selects focus follows mouse mode")
  func dispatchSelectsFocusFollowsMouseMode() {
    let spaces = Spaces(activeSpaceID: nil)
    let windows = Windows(workspace: Workspace())
    let handler = ConfigCommandHandler(
      windows: windows,
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces)
    )

    let autofocus = handler.dispatch(
      request(command: "focus-follows-mouse", args: ["autofocus"])
    )
    let autoraise = handler.dispatch(
      request(command: "focus-follows-mouse", args: ["autoraise"])
    )
    let disabled = handler.dispatch(request(command: "focus-follows-mouse", args: ["off"]))
    let invalid = handler.dispatch(request(command: "focus-follows-mouse", args: ["on"]))

    #expect(autofocus.ok && autofocus.message == "autofocus")
    #expect(autoraise.ok && autoraise.message == "autoraise")
    #expect(disabled.ok && disabled.message == "off")
    #expect(!invalid.ok && invalid.errorCode == .invalidRequest)
  }

  @Test("dispatch: padding updates defaults and preserves other override sides")
  func dispatchPaddingUpdatesDefaultsAndPreservesOtherOverrideSides() {
    let spaces = Spaces(activeSpaceID: nil)
    spaces.setPadding(
      SpacePadding(top: 1, bottom: 2, left: 3, right: 4),
      for: 1
    )
    let handler = handler(spaces: spaces)

    let response = handler.dispatch(request(command: "top-padding", args: ["10"]))

    #expect(response.ok)
    #expect(spaces.settings(for: 1).padding == SpacePadding(top: 10, bottom: 2, left: 3, right: 4))
    #expect(spaces.settings(for: 2).padding == SpacePadding(top: 10, bottom: 0, left: 0, right: 0))
  }

  @Test(
    "dispatch rejects malformed arguments with exact diagnostics",
    arguments: [
      ("window-gap", [], "invalid config window-gap arguments"),
      ("window-gap", ["10", "20"], "invalid config window-gap arguments"),
      ("window-gap", ["wide"], "invalid config window-gap value: wide"),
      ("top-padding", [], "invalid config top-padding arguments"),
      ("top-padding", ["10", "20"], "invalid config top-padding arguments"),
      ("right-padding", ["wide"], "invalid config right-padding value: wide"),
      ("layout", [], "invalid config layout arguments"),
      ("layout", ["master", "dwindle"], "invalid config layout arguments"),
      ("layout", ["columns"], "invalid config layout: columns"),
      ("master-ratio", ["wide"], "invalid config master-ratio value: wide"),
      ("master-placement", ["center"], "invalid config master-placement: center"),
      ("preserve-split", ["maybe"], "invalid config preserve-split value: maybe"),
      ("focus-follows-mouse", ["maybe"], "invalid config focus-follows-mouse value: maybe"),
    ]
  )
  func malformedArguments(command: String, args: [String], message: String) {
    let response = handler(spaces: Spaces(activeSpaceID: nil)).dispatch(
      request(command: command, args: args)
    )
    #expect(!response.ok)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == message)
  }

  @Test("dispatch: validates animation duration")
  func animationDurationValidation() {
    let handler = handler(spaces: Spaces(activeSpaceID: nil))
    for argument in ["0", "0.18", "1"] {
      #expect(handler.dispatch(request(command: "animation-duration", args: [argument])).ok)
    }
    for args in [[], ["-1"], ["1.1"], ["nan"], ["inf"], ["fast"], ["0.1", "0.2"]] {
      let response = handler.dispatch(request(command: "animation-duration", args: args))
      #expect(!response.ok)
      #expect(response.errorCode == .invalidRequest)
    }
  }

  @Test("dispatch: validates and applies animation easing")
  func animationEasingValidation() {
    let spaces = Spaces(activeSpaceID: nil)
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in .zero },
      frameMutation: { _, _, _ in .success }
    )
    let handler = ConfigCommandHandler(
      windows: Windows(workspace: Workspace()),
      spaces: spaces,
      tiling: makeTiling(frameReconciler: reconciler)
    )
    for easing in AnimationEasing.allCases {
      let response = handler.dispatch(request(command: "animation-easing", args: [easing.rawValue]))
      #expect(response.ok)
      #expect(reconciler.animationEasing == easing)
    }
    let previous = reconciler.animationEasing
    for args in [[], ["unknown"], ["linear", "ease-out-quad"]] {
      let response = handler.dispatch(request(command: "animation-easing", args: args))
      #expect(!response.ok)
      #expect(response.errorCode == .invalidRequest)
      #expect(reconciler.animationEasing == previous)
    }
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .config, command: command, args: args)
  }

  private func layoutID(_ spaceID: UInt64) -> TilingLayoutID {
    TilingLayoutID(spaceID: spaceID, displayID: "display")
  }

  private func handler(spaces: Spaces) -> ConfigCommandHandler {
    ConfigCommandHandler(
      windows: Windows(workspace: Workspace()),
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces)
    )
  }
}
