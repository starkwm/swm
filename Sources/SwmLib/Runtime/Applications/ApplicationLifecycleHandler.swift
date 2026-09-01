import Dispatch

/// Handles application lifecycle events and starts or stops application/window management.
@MainActor
struct ApplicationLifecycleHandler {
  /// Workspace bridge used for AppKit readiness and observability checks.
  let workspace: Workspace

  /// Process service used to retry launch handling.
  let processes: Processes

  /// Window service updated by application lifecycle changes.
  let windows: Windows

  /// Tiling coordinator reconciled after application inventory changes.
  let tiling: Tiling

  /// Handle one application lifecycle event.
  func handle(_ event: ApplicationEvent) {
    switch event {
    case .launched(let process):
      applicationLaunched(for: process)
    case .terminated(let process):
      applicationTerminated(for: process)
    case .frontSwitched(let process):
      applicationFrontSwitched(for: process)
    }
  }

  /// Make a launched process observable and discover its windows.
  private func applicationLaunched(for process: Process) {
    if process.terminated {
      windows.removeLostFrontSwitchedEvent(for: process.pid)
      log("application terminated during launch \(process)", level: .info)
      return
    }

    if !workspace.isFinishedLaunching(process) {
      log("application has not finished launching \(process)", level: .info)
      workspace.observeFinishedLaunching(process)
      guard workspace.isFinishedLaunching(process) else { return }
      workspace.unobserveFinishedLaunching(process)
    }

    if !workspace.isObservable(process) {
      log("application is not observable \(process)", level: .info)
      workspace.observeActivationPolicy(process)
      guard workspace.isObservable(process) else { return }
      workspace.unobserveActivationPolicy(process)
    }

    guard
      let application = windows.manage(
        process,
        retryObservation: {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            [processes, psn = process.psn] in
            guard let process = processes.find(by: psn) else { return }
            Events.shared.post(.application(.launched(process)))
          }
        }
      )
    else { return }

    windows.addWindows(for: application)
    tiling.reconcileAndReflowVisibleSpaces()
    emitApplicationSignal(.applicationLaunched, application: application)

    if windows.removeLostFrontSwitchedEvent(for: process.pid) {
      Events.shared.post(.application(.frontSwitched(process)))
    }

    log("application launched \(application)")
  }

  /// Stop observing a terminated application and remove its windows.
  private func applicationTerminated(for process: Process) {
    workspace.unobserveActivationPolicy(process)
    workspace.unobserveFinishedLaunching(process)
    windows.removeLostFrontSwitchedEvent(for: process.pid)

    guard let application = windows.application(by: process.pid) else { return }

    log("application terminated \(application)")

    windows.remove(application: application)
    emitApplicationSignal(.applicationTerminated, application: application)

    let applicationWindows = windows.allWindows(for: application)

    for window in applicationWindows {
      windows.remove(by: window.id)
    }

    tiling.reconcileAndReflowVisibleSpaces()

    for window in applicationWindows {
      window.invalidate()
    }

    application.unobserve()
  }

  /// Refresh windows and publish focused-window events after a frontmost app switch.
  private func applicationFrontSwitched(for process: Process) {
    guard let application = windows.application(by: process.pid) else {
      windows.addLostFrontSwitchedEvent(for: process.pid)
      log("frontmost application switched before launch completed \(process)", level: .info)
      return
    }

    windows.refreshWindows(for: application)

    if let focusedWindowID = application.focusedWindowID() {
      Events.shared.post(.window(.focused(focusedWindowID)))
    }

    log(
      "frontmost application switched \(application), current focused window: \(windows.currentFocusedWindowID.map(String.init) ?? "nil"), last focused window: \(windows.lastFocusedWindowID.map(String.init) ?? "nil")"
    )
  }

  /// Emit an application lifecycle signal after the model state changes.
  private func emitApplicationSignal(_ event: SignalEvent, application: Application) {
    Signals.shared.emit(
      .application(
        event: event,
        processID: application.processID,
        app: application.name,
        active: WindowServerClient.shared.frontmostProcessID() == application.processID
      )
    )
  }
}
