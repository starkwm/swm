import Carbon
import Testing

@testable import SwmLib

@Suite("EventManager")
struct EventManagerTests {
  @Test("post: accepts application events")
  func postAcceptsApplicationEvents() {
    let psn = ProcessSerialNumber(highLongOfPSN: 1, lowLongOfPSN: 2)
    let process = Process(psn: psn, pid: 42, name: "Example")
    let workspace = Workspace()

    EventManager.shared.configure(
      processLookup: ProcessManager(),
      workspace: workspace,
      windowManager: WindowManager(workspace: workspace)
    )
    EventManager.shared.post(.application(.launched(process)))
  }

  @Test("post: accepts space events")
  func postAcceptsSpaceEvents() {
    configureEventManager()
    let space = Space(id: 1, type: .normal)

    EventManager.shared.post(.space(.changed(space)))
  }

  @Test("post: accepts display events")
  func postAcceptsDisplayEvents() {
    configureEventManager()
    EventManager.shared.post(.display(.changed))
  }

  @Test("post: accepts window events")
  func postAcceptsWindowEvents() {
    configureEventManager()
    EventManager.shared.post(.window(.created(42, 1)))
    EventManager.shared.post(.window(.focused(1)))
    EventManager.shared.post(.window(.moved(1)))
    EventManager.shared.post(.window(.resized(1)))
  }

  private func configureEventManager() {
    let workspace = Workspace()
    EventManager.shared.configure(
      processLookup: ProcessManager(),
      workspace: workspace,
      windowManager: WindowManager(workspace: workspace)
    )
  }
}
