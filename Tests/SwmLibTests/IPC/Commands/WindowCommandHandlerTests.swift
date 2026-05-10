import CoreGraphics
import Testing

@testable import SwmLib

@Suite("WindowCommandHandler")
struct WindowCommandHandlerTests {
  @Test("dispatch: rejects malformed single-target action arguments")
  func dispatchRejectsMalformedSingleTargetActionArguments() {
    let handler = handler()

    for action in ["focus", "minimize", "unminimize"] {
      let extra = handler.dispatch(request(command: "--\(action)", args: ["1", "2"]))

      #expect(extra.ok == false)
      #expect(extra.errorCode == .invalidRequest)
      #expect(extra.message == "invalid window \(action) arguments")
    }
  }

  @Test("dispatch: rejects invalid single-target action target")
  func dispatchRejectsInvalidSingleTargetActionTarget() {
    let handler = handler()

    for action in ["focus", "minimize", "unminimize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["nope"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window selector: nope")
    }
  }

  @Test("dispatch: rejects missing numeric single-target action target")
  func dispatchRejectsMissingNumericSingleTargetActionTarget() {
    let handler = handler()

    for action in ["focus", "minimize", "unminimize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["42"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "window not found: 42")
    }
  }

  @Test("dispatch: rejects malformed geometry action arguments")
  func dispatchRejectsMalformedGeometryActionArguments() {
    let handler = handler()

    for action in ["move", "resize"] {
      let missing = handler.dispatch(request(command: "--\(action)", args: []))
      let extra = handler.dispatch(
        request(command: "--\(action)", args: ["1", "abs:1:2", "extra"])
      )

      #expect(missing.ok == false)
      #expect(missing.errorCode == .invalidRequest)
      #expect(missing.message == "invalid window \(action) arguments")
      #expect(extra.ok == false)
      #expect(extra.errorCode == .invalidRequest)
      #expect(extra.message == "invalid window \(action) arguments")
    }
  }

  @Test("dispatch: rejects invalid geometry action value")
  func dispatchRejectsInvalidGeometryActionValue() {
    let handler = handler()

    for action in ["move", "resize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["rel:100:x"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window \(action) value: rel:100:x")
    }
  }

  @Test("dispatch: rejects geometry action with invalid window selector")
  func dispatchRejectsGeometryActionWithInvalidWindowSelector() {
    let handler = handler()

    for action in ["move", "resize"] {
      let response = handler.dispatch(
        request(command: "--\(action)", args: ["nope", "rel:100:-200"])
      )

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window selector: nope")
    }
  }

  @Test("dispatch: rejects malformed grid arguments")
  func dispatchRejectsMalformedGridArguments() {
    let handler = handler()
    let missing = handler.dispatch(request(command: "--grid", args: []))
    let extra = handler.dispatch(request(command: "--grid", args: ["1", "1:2:3:4:5:6", "extra"]))

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid window grid arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid window grid arguments")
  }

  @Test("dispatch: rejects invalid grid value")
  func dispatchRejectsInvalidGridValue() {
    let handler = handler()
    let response = handler.dispatch(request(command: "--grid", args: ["1:3:0:0:2:x"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window grid value: 1:3:0:0:2:x")
  }

  @Test("dispatch: rejects grid with invalid window selector")
  func dispatchRejectsGridWithInvalidWindowSelector() {
    let handler = handler()
    let response = handler.dispatch(request(command: "--grid", args: ["nope", "3:1:0:0:2:1"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window selector: nope")
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .window, command: command, args: args)
  }

  private func handler(
    windowManager: WindowManager = WindowManager(workspace: Workspace())
  ) -> WindowCommandHandler {
    WindowCommandHandler(
      windowManager: windowManager,
      spaceManager: SpaceManager(activeSpaceID: nil)
    )
  }
}

@Suite("WindowGrid")
struct WindowGridTests {
  @Test("init: clamps position and size")
  func initClampsPositionAndSize() throws {
    let grid = try #require(WindowGrid(argument: "3:2:99:99:99:0"))

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 120), settings: .defaults),
      equals: CGRect(x: 200, y: 60, width: 100, height: 60)
    )
  }

  @Test("frame: places window in left two thirds")
  func framePlacesWindowInLeftTwoThirds() throws {
    let grid = try #require(WindowGrid(argument: "3:1:0:0:2:1"))

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 120), settings: .defaults),
      equals: CGRect(x: 0, y: 0, width: 200, height: 120)
    )
  }

  @Test("frame: applies gap before right third")
  func frameAppliesGapBeforeRightThird() throws {
    let grid = try #require(WindowGrid(argument: "3:1:2:0:1:1"))
    var settings = SpaceSettings.defaults
    settings.gap = 15

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 120), settings: settings),
      equals: CGRect(x: 205, y: 0, width: 95, height: 120)
    )
  }

  @Test("frame: applies trailing gap when grid area remains")
  func frameAppliesTrailingGapWhenGridAreaRemains() throws {
    let grid = try #require(WindowGrid(argument: "3:1:0:0:2:1"))
    var settings = SpaceSettings.defaults
    settings.gap = 15

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 120), settings: settings),
      equals: CGRect(x: 0, y: 0, width: 190, height: 120)
    )
  }

  @Test("frame: applies per-side padding")
  func frameAppliesPerSidePadding() throws {
    let grid = try #require(WindowGrid(argument: "1:1:0:0:1:1"))
    var settings = SpaceSettings.defaults
    settings.padding = SpacePadding(top: 10, bottom: 20, left: 30, right: 40)

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 200), settings: settings),
      equals: CGRect(x: 30, y: 10, width: 230, height: 170)
    )
  }

  @Test("frame: ignores disabled padding and gap")
  func frameIgnoresDisabledPaddingAndGap() throws {
    let grid = try #require(WindowGrid(argument: "3:1:1:0:1:1"))
    var settings = SpaceSettings.defaults
    settings.paddingEnabled = false
    settings.gapEnabled = false
    settings.padding = SpacePadding(top: 10, bottom: 10, left: 10, right: 10)
    settings.gap = 15

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 120), settings: settings),
      equals: CGRect(x: 100, y: 0, width: 100, height: 120)
    )
  }

  private func expect(_ actual: CGRect, equals expected: CGRect) {
    #expect(abs(actual.origin.x - expected.origin.x) < 0.0001)
    #expect(abs(actual.origin.y - expected.origin.y) < 0.0001)
    #expect(abs(actual.size.width - expected.size.width) < 0.0001)
    #expect(abs(actual.size.height - expected.size.height) < 0.0001)
  }
}
