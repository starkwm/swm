import ApplicationServices
import Carbon
import Foundation

public final class WindowManager {
  private let workspace: Workspace

  private static func resolveFocusedWindowID() -> CGWindowID? {
    guard let processID = WindowServerClient.shared.frontmostProcessID() else {
      return nil
    }

    let applicationElement = AccessibilityClient.shared.applicationElement(for: processID)

    guard
      let focusedWindowElement = AccessibilityClient.shared.focusedWindowElement(
        for: applicationElement
      )
    else {
      return nil
    }

    return Window.validID(for: focusedWindowElement)
  }

  var currentFocusedWindowID: CGWindowID? {
    focusedWindowLock.withLock {
      focusedWindow.current
    }
  }

  var lastFocusedWindowID: CGWindowID? {
    focusedWindowLock.withLock {
      focusedWindow.last
    }
  }

  private let focusedWindowLock = NSLock()
  private var focusedWindow: TrackedState<CGWindowID>

  private var applicationsByPID = [pid_t: Application]()
  private var unresolvedApplicationIDs = Set<pid_t>()
  private var windowsByID = [CGWindowID: Window]()

  public convenience init(workspace: Workspace) {
    self.init(workspace: workspace, focusedWindowID: Self.resolveFocusedWindowID())
  }

  init(workspace: Workspace, focusedWindowID: CGWindowID?) {
    self.workspace = workspace
    focusedWindow = TrackedState(current: focusedWindowID)
  }

  public func start(processes: [Process]) {
    for process in processes {
      startManaging(process)
    }
  }

  func application(by pid: pid_t) -> Application? {
    applicationsByPID[pid]
  }

  func application(by name: String) -> Application? {
    applicationsByPID.values.first { $0.name == name }
  }

  func allApplications() -> [Application] {
    Array(applicationsByPID.values)
  }

  func window(by id: CGWindowID) -> Window? {
    windowsByID[id]
  }

  func allWindows(for application: Application) -> [Window] {
    windowsByID.values.filter { $0.application == application }
  }

  func allWindows() -> [Window] {
    Array(windowsByID.values)
  }

  func focusedWindowDidChange(to windowID: CGWindowID) {
    guard windowID != 0 else { return }

    focusedWindowLock.withLock {
      focusedWindow.update(to: windowID)
    }
  }

  func refreshWindows() {
    for processID in Array(unresolvedApplicationIDs) {
      guard let application = applicationsByPID[processID] else {
        unresolvedApplicationIDs.remove(processID)
        continue
      }

      refreshWindows(for: application)
    }
  }

  func refreshWindows(for application: Application) {
    guard unresolvedApplicationIDs.contains(application.processID) else { return }

    log("application has windows that are not yet resolved \(application)", level: .info)
    _ = reconcileWindows(for: application, mode: .refreshAttempt)
  }

  func add(application: Application) {
    applicationsByPID[application.processID] = application
  }

  func remove(application: Application) {
    unresolvedApplicationIDs.remove(application.processID)
    applicationsByPID.removeValue(forKey: application.processID)
  }

  @discardableResult
  func addWindow(for application: Application, with element: AXUIElement) -> Window? {
    let window = Window(with: element, for: application)

    guard window.subrole != nil else { return nil }

    guard window.observe() else {
      window.unobserve()
      return nil
    }

    windowsByID[window.id] = window

    return window
  }

  @discardableResult
  func addWindows(for application: Application) -> [Window] {
    let elements = application.windowElements()
    var windows = [Window]()

    for element in elements {
      guard let windowID = Window.validID(for: element), windowsByID[windowID] == nil else {
        continue
      }

      if let window = addWindow(for: application, with: element) {
        windows.append(window)
      }
    }

    return windows
  }

  func remove(by windowID: CGWindowID) {
    windowsByID.removeValue(forKey: windowID)
  }

  @discardableResult
  private func reconcileWindows(
    for application: Application,
    mode: WindowDiscoveryMode
  ) -> Bool {
    let globalWindowIDs = application.windowIdentifiers()
    let accessibilityElements = application.windowElements()
    let resolvedWindowCount = registerAccessibleWindows(
      for: application,
      elements: accessibilityElements
    )

    if globalWindowIDs.count == resolvedWindowCount {
      return finishResolution(for: application, mode: mode)
    }

    var unresolvedWindowIDs = globalWindowIDs.filter { windowsByID[$0] == nil }

    guard !unresolvedWindowIDs.isEmpty else {
      return finishResolution(for: application, mode: mode)
    }

    resolveRemoteWindows(&unresolvedWindowIDs, for: application)

    return updateRefreshTracking(
      for: application,
      unresolvedWindowIDs: unresolvedWindowIDs,
      mode: mode
    )
  }

  private func startManaging(_ process: Process) {
    guard workspace.isObservable(process) else {
      log("application is not observable \(process)", level: .warn)
      workspace.observeActivationPolicy(process)
      return
    }

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
      return
    }

    add(application: application)
    _ = reconcileWindows(for: application, mode: .initialDiscovery)
  }

  private func registerAccessibleWindows(
    for application: Application,
    elements: [AXUIElement]
  ) -> Int {
    var resolvedWindowCount = 0

    for element in elements {
      guard let windowID = Window.validID(for: element) else { continue }

      resolvedWindowCount += 1

      if windowsByID[windowID] == nil {
        _ = addWindow(for: application, with: element)
      }
    }

    return resolvedWindowCount
  }

  private func finishResolution(for application: Application, mode: WindowDiscoveryMode) -> Bool {
    guard mode == .refreshAttempt else { return false }
    log("all windows resolved \(application)", level: .info)
    unresolvedApplicationIDs.remove(application.processID)
    return true
  }

  private func resolveRemoteWindows(
    _ unresolvedWindowIDs: inout [CGWindowID],
    for application: Application
  ) {
    log(
      "application has windows that are not resolved, attempting workaround \(application)",
      level: .info
    )

    for id in 0...0x7fff {
      guard !unresolvedWindowIDs.isEmpty else { break }

      let token = createRemoteToken(for: application.processID, with: id)

      guard
        let element = _AXUIElementCreateWithRemoteToken(token)?.takeRetainedValue(),
        Window.isWindow(element),
        let windowID = Window.validID(for: element)
      else {
        continue
      }

      if let index = unresolvedWindowIDs.firstIndex(of: windowID) {
        unresolvedWindowIDs.remove(at: index)
        _ = addWindow(for: application, with: element)
        log("resolved window \(windowID) for \(application)", level: .info)
      }
    }
  }

  private func createRemoteToken(for pid: pid_t, with id: Int) -> CFData {
    var token = Data()

    token.append(contentsOf: withUnsafeBytes(of: pid) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0x636f_636f)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: id) { Data($0) })

    return token as CFData
  }

  private func updateRefreshTracking(
    for application: Application,
    unresolvedWindowIDs: [CGWindowID],
    mode: WindowDiscoveryMode
  ) -> Bool {
    switch mode {
    case .initialDiscovery:
      if !unresolvedWindowIDs.isEmpty {
        log("workaround failed to resolve all windows \(application)", level: .warn)
        unresolvedApplicationIDs.insert(application.processID)
      }

    case .refreshAttempt:
      if unresolvedWindowIDs.isEmpty {
        log("workaround successfully resolved all windows \(application)", level: .info)
        unresolvedApplicationIDs.remove(application.processID)
        return true
      }
    }

    return false
  }
}

extension WindowManager: @unchecked Sendable {}

private enum WindowDiscoveryMode {
  case initialDiscovery
  case refreshAttempt
}
