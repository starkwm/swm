import Foundation

struct ApplicationLifecycleHandler {
  let workspace: Workspace
  let processManager: ProcessManager
  let windowManager: WindowManager

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
      log("application is not observable \(process)", level: .warn)
      workspace.observeActivationPolicy(process)
      guard workspace.isObservable(process) else { return }
      workspace.unobserveActivationPolicy(process)
    }

    guard windowManager.application(by: process.pid) == nil else { return }

    guard let application = Application(for: process) else {
      log("could not create application for process \(process)", level: .warn)
      return
    }

    switch application.observe() {
    case .success:
      break
    case .failure(let error):
      log("could not observe application \(application): \(error)", level: .warn)
      application.unobserve()

      if application.retryObserving {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          [processManager, psn = process.psn] in
          guard let process = processManager.find(by: psn) else { return }
          EventManager.shared.post(.application(.launched(process)))
        }
      }

      return
    }

    windowManager.add(application: application)
    _ = windowManager.addWindows(for: application)

    log("application launched \(application)")
  }

  private func applicationTerminated(for process: Process) {
    workspace.unobserveActivationPolicy(process)
    workspace.unobserveFinishedLaunching(process)

    guard let application = windowManager.application(by: process.pid) else { return }

    log("application terminated \(application)")

    windowManager.remove(application: application)

    let windows = windowManager.allWindows(for: application)

    for window in windows {
      windowManager.remove(by: window.id)
      window.invalidate()
    }

    application.unobserve()
  }

  private func applicationFrontSwitched(for process: Process) {
    guard let application = windowManager.application(by: process.pid) else { return }

    windowManager.refreshWindows(for: application)

    if let focusedWindowID = application.focusedWindowID() {
      windowManager.focusedWindowDidChange(to: focusedWindowID)
    }

    log(
      "frontmost application switched \(application), current focused window: \(windowManager.currentFocusedWindowID.map(String.init) ?? "nil"), last focused window: \(windowManager.lastFocusedWindowID.map(String.init) ?? "nil")"
    )
  }
}
