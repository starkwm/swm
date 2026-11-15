import ApplicationServices
import Dispatch

@MainActor
struct WindowLifecycleHandler {
  let windows: Windows

  let tiling: Tiling

  func handle(_ event: WindowEvent) {
    switch event {
    case .created(let pid, let windowID):
      windowCreated(for: pid, with: windowID)
    case .destroyed(let window):
      windowDestroyed(with: window)
    case .focused(let windowID):
      windowFocused(with: windowID)
    case .moved(let windowID), .resized(let windowID):
      windowFrameChanged(with: windowID)
    case .titleChanged(let windowID):
      tiling.windowTitleDidChange(windowID)
    case .minimized(let window):
      windowMinimized(with: window)
    case .deminimized(let window):
      windowDeminimized(with: window)
    }
  }

  private func windowCreated(for pid: pid_t, with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard windows.window(by: windowID) == nil else { return }
    guard let application = windows.application(by: pid) else { return }

    guard let window = windows.addWindow(with: windowID, for: application) else { return }

    log("window created \(window)")
    tiling.reconcileAndReflowVisibleSpaces()

    windows.replayLostFocusedEvent(for: window.id)
  }

  private func windowDestroyed(with window: Window) {
    guard window.id != 0 else { return }

    log("window destroyed \(window)")

    tiling.cancelAnimation(for: window.id)
    let processID = window.application?.processID
    windows.remove(by: window.id)
    window.invalidate()

    guard let processID else {
      tiling.reconcileAndReflowVisibleSpaces()
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [windows, tiling] in
      guard let application = windows.application(by: processID) else { return }
      windows.addWindows(for: application)
      tiling.reconcileAndReflowVisibleSpaces()
    }
  }

  private func windowFocused(with windowID: CGWindowID) {
    guard windowID != 0 else { return }

    if windows.window(by: windowID) == nil {
      if let window = windows.recoverFocusedWindow(with: windowID) {
        log("recovered focused window \(window)")
        tiling.reconcileAndReflowVisibleSpaces()
      }
    }

    guard let window = windows.window(by: windowID) else {
      windows.addLostFocusedEvent(for: windowID)
      log("window focused before it was managed id: \(windowID)")
      return
    }

    guard !window.isMinimized else {
      windows.addLostFocusedEvent(for: windowID)
      log("window focused while minimized \(window)")
      return
    }

    windows.removeLostFocusedEvent(for: windowID)
    windows.focusedWindowDidChange(to: windowID)
    tiling.windowDidFocus(windowID)

    log("window focused \(window) \(windows.focusedWindowState)")
  }

  private func windowFrameChanged(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    tiling.windowFrameDidChange(windowID)
  }

  private func windowMinimized(with window: Window) {
    tiling.cancelAnimation(for: window.id)
    log("window minimized \(window)")
    tiling.reconcileAndReflowVisibleSpaces()
  }

  private func windowDeminimized(with window: Window) {
    log("window deminimized \(window)")
    tiling.reconcileAndReflowVisibleSpaces()

    windows.replayLostFocusedEvent(for: window.id)
  }
}
