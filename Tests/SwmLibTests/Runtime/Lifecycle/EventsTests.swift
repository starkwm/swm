import Dispatch
import Testing

@testable import SwmLib

@Suite("Events")
@MainActor
struct EventsTests {
  @Test("queued lifecycle events preserve order and capture destruction facts before invalidation")
  func orderedDestruction() async {
    let windows = Windows(workspace: Workspace(), focusedWindowID: 42)
    let mapper = RuntimeEventSignalMapper(
      windows: windows,
      spaces: Spaces(activeSpaceID: nil),
      displays: Displays()
    )
    var handled = [String]()
    var destructionPayload: SignalPayload?
    let events = Events { event in
      switch event {
      case .window(.minimized(let window)):
        handled.append("minimized:\(window.id)")
      case .window(.deminimized(let window)):
        handled.append("deminimized:\(window.id)")
      case .window(.destroyed(let window)):
        handled.append("destroyed:\(window.id)")
        destructionPayload = mapper.payload(beforeHandling: event)
        window.invalidate()
      default: Issue.record("Unexpected event")
      }
    }
    weak var retainedWindow: Window?
    do {
      let window = Window(id: 42)
      retainedWindow = window
      events.post(.window(.minimized(window)))
      events.post(.window(.deminimized(window)))
      events.post(.window(.destroyed(window)))
    }
    #expect(retainedWindow != nil)
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }
    #expect(handled == ["minimized:42", "deminimized:42", "destroyed:42"])
    #expect(destructionPayload?.event == .windowDestroyed)
    #expect(destructionPayload?.environment["SWM_WINDOW_ID"] == "42")
    #expect(destructionPayload?.active == true)
    #expect(retainedWindow == nil)
  }
}
