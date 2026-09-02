import ApplicationServices
import Dispatch

/// Handles window lifecycle and focus events.
@MainActor
struct WindowLifecycleHandler {
  /// Window service updated by window events.
  let windows: Windows

  /// Tiling coordinator updated by window lifecycle events.
  let tiling: Tiling

  /// Handle one window lifecycle event.
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
    case .minimized(let window):
      windowMinimized(with: window)
    case .deminimized(let window):
      windowDeminimized(with: window)
    }
  }

  /// Add a newly created window and replay any deferred focus event for it.
  private func windowCreated(for pid: pid_t, with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard windows.window(by: windowID) == nil else { return }
    guard let application = windows.application(by: pid) else { return }

    guard let window = windows.addWindow(with: windowID, for: application) else { return }

    log("window created \(window)")
    tiling.reconcileAndReflowVisibleSpaces()

    if windows.removeLostFocusedEvent(for: window.id) {
      Events.shared.post(.window(.focused(window.id)))
    }
  }

  /// Remove and invalidate a destroyed managed window.
  private func windowDestroyed(with window: Window) {
    guard window.id != 0 else { return }

    log("window destroyed \(window)")

    let processID = window.application?.processID
    windows.remove(by: window.id)
    window.invalidate()

    guard let processID else {
      tiling.reconcileAndReflowVisibleSpaces()
      return
    }

    // Native macOS tabs destroy one AX window before WindowServer exposes the surviving tab's
    // updated Space membership. Let that transition settle, then rediscover and reflow once.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [windows, tiling] in
      guard let application = windows.application(by: processID) else { return }
      windows.addWindows(for: application)
      tiling.reconcileAndReflowVisibleSpaces()
    }
  }

  /// Update focus tracking or defer the focus event until the window is manageable.
  private func windowFocused(with windowID: CGWindowID) {
    guard windowID != 0 else { return }

    guard let window = windows.window(by: windowID) else {
      windows.addLostFocusedEvent(for: windowID)
      log("window focused before it was managed id: \(windowID)", level: .info)
      return
    }

    guard !window.isMinimized else {
      windows.addLostFocusedEvent(for: windowID)
      log("window focused while minimized \(window)", level: .info)
      return
    }

    windows.removeLostFocusedEvent(for: windowID)
    windows.focusedWindowDidChange(to: windowID)
    tiling.windowDidFocus(windowID)

    log(
      "window focused \(window) current: \(windows.currentFocusedWindowID.map(String.init) ?? "nil"), last: \(windows.lastFocusedWindowID.map(String.init) ?? "nil")"
    )
  }

  /// Handle a window move or resize notification.
  private func windowFrameChanged(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    tiling.windowFrameDidChange(windowID)
  }

  /// Handle a window minimization notification.
  private func windowMinimized(with window: Window) {
    log("window minimized \(window)")
    tiling.reconcileAndReflowVisibleSpaces()
  }

  /// Handle a window restore notification and replay deferred focus.
  private func windowDeminimized(with window: Window) {
    log("window deminimized \(window)")
    tiling.reconcileAndReflowVisibleSpaces()

    if windows.removeLostFocusedEvent(for: window.id) {
      Events.shared.post(.window(.focused(window.id)))
    }
  }
}
