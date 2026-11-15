@MainActor
struct ApplicationLifecycleHandler {
  let workspace: Workspace

  let processes: Processes

  let windows: Windows

  let tiling: Tiling

  var postEvent: (RuntimeEvent) -> Void = { Events.shared.post($0) }

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

  private func applicationLaunched(for process: Process) {
    if process.terminated {
      windows.removeLostFrontSwitchedEvent(for: process.pid)
      log("application terminated during launch \(process)")
      return
    }

    let retry = {
      windows.retryDiscovery(
        for: process,
        resolveProcess: { processes.find(by: process.psn) },
        retry: { postEvent(.application(.launched(process))) }
      )
    }

    if !workspace.isFinishedLaunching(process) {
      log("application has not finished launching \(process)")
      guard workspace.observeUntilFinishedLaunching(process) else {
        if process.application == nil { retry() }
        return
      }
    }

    if !workspace.isObservable(process) {
      log("application is not observable \(process)")
      workspace.observeActivationPolicy(process)
      guard workspace.isObservable(process) else { return }
      workspace.unobserveActivationPolicy(process)
    }

    let wasManaged = windows.application(by: process.pid) != nil
    guard
      let application = windows.manage(
        process,
        retryObservation: retry
      )
    else { return }

    if windows.refreshWindows(for: application) {
      windows.resetDiscoveryRetries(for: process)
    } else {
      retry()
    }
    tiling.reconcileAndReflowVisibleSpaces()
    if !wasManaged { emitApplicationSignal(.applicationLaunched, application: application) }

    if windows.removeLostFrontSwitchedEvent(for: process.pid) {
      postEvent(.application(.frontSwitched(process)))
    }

    log("application launched \(application)")
  }

  private func applicationTerminated(for process: Process) {
    windows.cancelDiscoveryRetry(for: process)
    workspace.unobserveActivationPolicy(process)
    workspace.unobserveFinishedLaunching(process)
    windows.removeLostFrontSwitchedEvent(for: process.pid)

    guard let application = windows.application(by: process.pid) else { return }

    log("application terminated \(application)")

    windows.remove(application: application)
    emitApplicationSignal(.applicationTerminated, application: application)

    let applicationWindows = windows.allWindows(for: application)

    for window in applicationWindows {
      tiling.cancelAnimation(for: window.id)
      windows.remove(by: window.id)
    }

    tiling.reconcileAndReflowVisibleSpaces()

    for window in applicationWindows {
      window.invalidate()
    }

    application.unobserve()
  }

  private func applicationFrontSwitched(for process: Process) {
    guard let application = windows.application(by: process.pid) else {
      windows.addLostFrontSwitchedEvent(for: process.pid)
      log("frontmost application is unmanaged, retrying launch handling \(process)")
      applicationLaunched(for: process)
      return
    }

    windows.refreshWindows(for: application)
    tiling.reconcileAndReflowVisibleSpaces()

    if let focusedWindowID = application.focusedWindowID() {
      postEvent(.window(.focused(focusedWindowID)))
    }

    log(
      "frontmost application switched \(application), current focused window: \(windows.currentFocusedWindowID.map(String.init) ?? "nil"), last focused window: \(windows.lastFocusedWindowID.map(String.init) ?? "nil")"
    )
  }

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
