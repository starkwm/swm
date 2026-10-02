import CoreGraphics
import Testing

@testable import SwmLib

@Suite("WindowMouseWarp")
@MainActor
struct WindowMouseWarpTests {
  @Test(
    "sourceWindow: prefers the on-screen managed window under the cursor without resolving focus"
  )
  func pointerSource() throws {
    let pointerWindow = Window(id: 42)
    let warp = WindowMouseWarp(
      isOnScreen: { $0 == 42 },
      cursorWindowID: { 42 }
    )

    let source = try warp.sourceWindow(
      windowByID: { $0 == 42 ? pointerWindow : nil },
      focusedWindow: { throw IPCCommandError.invalidRequest("no focused window") }
    )

    #expect(source === pointerWindow)
  }

  @Test(
    "sourceWindow: falls back to focus for missing, unmanaged, or off-screen pointer windows",
    arguments: [nil, 42, 99] as [CGWindowID?]
  )
  func focusedFallback(cursorID: CGWindowID?) throws {
    let pointerWindow = Window(id: 42)
    let focusedWindow = Window(id: 7)
    let warp = WindowMouseWarp(
      isOnScreen: { _ in false },
      cursorWindowID: { cursorID }
    )

    let source = try warp.sourceWindow(
      windowByID: { $0 == 42 ? pointerWindow : nil },
      focusedWindow: { focusedWindow }
    )

    #expect(source === focusedWindow)
  }

  @Test("sourceWindow: reads the cursor window again for successive navigation")
  func successiveSources() throws {
    let firstWindow = Window(id: 42)
    let secondWindow = Window(id: 43)
    var cursorID: CGWindowID = 42
    let warp = WindowMouseWarp(
      isOnScreen: { _ in true },
      cursorWindowID: { cursorID }
    )
    let lookup: (CGWindowID) -> Window? = { $0 == 42 ? firstWindow : secondWindow }

    let first = try warp.sourceWindow(windowByID: lookup, focusedWindow: { firstWindow })
    cursorID = 43
    let second = try warp.sourceWindow(windowByID: lookup, focusedWindow: { firstWindow })

    #expect(first === firstWindow)
    #expect(second === secondWindow)
  }

  @Test("sourceWindow: reports a missing focused window when the pointer has no managed window")
  func missingSource() {
    let warp = WindowMouseWarp(cursorWindowID: { nil })

    #expect(throws: IPCCommandError.invalidRequest("no focused window")) {
      try warp.sourceWindow(
        windowByID: { _ in nil },
        focusedWindow: { throw IPCCommandError.invalidRequest("no focused window") }
      )
    }
  }

  @Test(
    "warp: uses global coordinates on primary and offset displays",
    arguments: [
      CGRect(x: 10, y: 20, width: 80, height: 60),
      CGRect(x: -490, y: -180, width: 80, height: 60),
    ]
  )
  func windowCenter(frame: CGRect) throws {
    var received: CGPoint?
    let warp = WindowMouseWarp(
      isOnScreen: { windowID in windowID == 42 },
      displayFrames: {
        [
          CGRect(x: 0, y: 0, width: 500, height: 400),
          CGRect(x: -500, y: -200, width: 500, height: 400),
        ]
      },
      warpCursor: {
        received = $0
        return .success
      }
    )

    try warp.warp(windowID: 42, frame: frame)

    #expect(received == CGPoint(x: frame.midX, y: frame.midY))
  }

  @Test("warp: uses the largest visible intersection when the center is off-screen")
  func visibleIntersection() throws {
    var received: CGPoint?
    let warp = WindowMouseWarp(
      isOnScreen: { _ in true },
      displayFrames: {
        [
          CGRect(x: 0, y: 0, width: 100, height: 100),
          CGRect(x: 200, y: 0, width: 100, height: 100),
        ]
      },
      warpCursor: {
        received = $0
        return .success
      }
    )

    try warp.warp(windowID: 42, frame: CGRect(x: 60, y: 10, width: 220, height: 80))

    #expect(received == CGPoint(x: 240, y: 50))
  }

  @Test("warp: rejects hidden, minimized, and off-Space windows before moving the cursor")
  func unavailableWindow() {
    let warp = WindowMouseWarp(
      isOnScreen: { _ in false },
      displayFrames: {
        Issue.record("Unexpected display query")
        return []
      },
      warpCursor: { _ in
        Issue.record("Unexpected cursor move")
        return .success
      }
    )

    #expect(throws: IPCCommandError.invalidRequest("window is not on screen: 42")) {
      try warp.warp(windowID: 42, frame: CGRect(x: 10, y: 20, width: 80, height: 60))
    }
  }

  @Test(
    "warp: rejects missing, empty, and non-finite frames",
    arguments: [
      nil,
      CGRect.zero,
      CGRect(x: 0, y: 0, width: -10, height: 100),
      CGRect(x: 0, y: 0, width: 100, height: -10),
      CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100),
      CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 100),
    ] as [CGRect?]
  )
  func invalidFrame(frame: CGRect?) {
    let warp = WindowMouseWarp(
      isOnScreen: { _ in true },
      displayFrames: {
        Issue.record("Unexpected display query")
        return []
      },
      warpCursor: { _ in
        Issue.record("Unexpected cursor move")
        return .success
      }
    )

    #expect(throws: IPCCommandError.internalError("could not read window frame: 42")) {
      try warp.warp(windowID: 42, frame: frame)
    }
  }

  @Test(
    "warp: rejects windows outside display bounds or with no connected displays",
    arguments: [
      [], [CGRect(x: 0, y: 0, width: 100, height: 100)],
    ] as [[CGRect]]
  )
  func outsideDisplay(frames: [CGRect]) {
    let warp = WindowMouseWarp(
      isOnScreen: { _ in true },
      displayFrames: { frames },
      warpCursor: { _ in
        Issue.record("Unexpected cursor move")
        return .success
      }
    )

    #expect(throws: IPCCommandError.invalidRequest("window has no on-screen bounds: 42")) {
      try warp.warp(windowID: 42, frame: CGRect(x: 200, y: 200, width: 80, height: 60))
    }
  }

  @Test("warp: reports Core Graphics failures")
  func cursorFailure() {
    let warp = WindowMouseWarp(
      isOnScreen: { _ in true },
      displayFrames: { [CGRect(x: 0, y: 0, width: 100, height: 100)] },
      warpCursor: { _ in .failure }
    )

    #expect(
      throws: IPCCommandError.internalError(
        "could not warp mouse cursor to window: 42; Core Graphics error: \(CGError.failure.rawValue)"
      )
    ) {
      try warp.warp(windowID: 42, frame: CGRect(x: 10, y: 20, width: 80, height: 60))
    }
  }
}
