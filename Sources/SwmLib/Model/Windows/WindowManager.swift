import ApplicationServices
import Carbon
import Foundation

/// Tracks observable applications, windows, and focused-window state.
public final class WindowManager {
  /// Resolve the currently focused window ID from the frontmost process.
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

    return AccessibilityClient.shared.optionalWindowID(for: focusedWindowElement)
  }

  /// ID of the currently focused window.
  var currentFocusedWindowID: CGWindowID? {
    focusedWindowLock.withLock {
      focusedWindowState.current
    }
  }

  /// ID of the previously focused window.
  var lastFocusedWindowID: CGWindowID? {
    focusedWindowLock.withLock {
      focusedWindowState.last
    }
  }

  private let workspace: Workspace
  private let focusedWindowLock = NSLock()
  private var focusedWindowState: TrackedState<CGWindowID>

  private var applicationsByPID = [pid_t: Application]()
  private var lostFrontSwitchedProcessIDs = Set<pid_t>()
  private var lostFocusedWindowIDs = Set<CGWindowID>()
  private var unresolvedApplicationIDs = Set<pid_t>()
  private var windowsByID = [CGWindowID: Window]()

  /// Create a window manager for a workspace.
  public init(workspace: Workspace) {
    self.workspace = workspace
    focusedWindowState = TrackedState(current: Self.resolveFocusedWindowID())
  }

  /// Start managing all supplied processes.
  public func start(processes: [Process]) {
    for process in processes {
      startManaging(process)
    }
  }

  /// Return a managed application by process ID.
  func application(by pid: pid_t) -> Application? {
    applicationsByPID[pid]
  }

  /// Return a managed window by Core Graphics window ID.
  func window(by id: CGWindowID) -> Window? {
    windowsByID[id]
  }

  /// Resolve the currently focused window ID.
  func focusedWindowID() -> CGWindowID? {
    Self.resolveFocusedWindowID()
  }

  /// Return the currently focused managed window.
  func focusedWindow() -> Window? {
    guard let windowID = focusedWindowID() else { return nil }
    return focusedWindow(by: windowID)
  }

  /// Return a focused managed window and update focused-window tracking.
  func focusedWindow(by windowID: CGWindowID) -> Window? {
    guard let window = window(by: windowID) else { return nil }

    focusedWindowDidChange(to: windowID)

    return window
  }

  /// Return all managed windows owned by an application.
  func allWindows(for application: Application) -> [Window] {
    windowsByID.values.filter { $0.application == application }
  }

  /// Return all managed windows.
  func allWindows() -> [Window] {
    Array(windowsByID.values)
  }

  /// Update focused-window tracking.
  func focusedWindowDidChange(to windowID: CGWindowID) {
    guard windowID != 0 else { return }

    focusedWindowLock.withLock {
      focusedWindowState.update(to: windowID)
    }
  }

  /// Retry discovery for applications with unresolved windows.
  func refreshWindows() {
    for processID in Array(unresolvedApplicationIDs) {
      guard let application = applicationsByPID[processID] else {
        unresolvedApplicationIDs.remove(processID)
        continue
      }

      refreshWindows(for: application)
    }
  }

  /// Retry window discovery for one application if it has unresolved windows.
  func refreshWindows(for application: Application) {
    guard unresolvedApplicationIDs.contains(application.processID) else { return }

    log("application has windows that are not yet resolved \(application)", level: .info)
    _ = reconcileWindows(for: application, mode: .refreshAttempt)
  }

  /// Record a front-switched event that arrived before its application was managed.
  func addLostFrontSwitchedEvent(for processID: pid_t) {
    lostFrontSwitchedProcessIDs.insert(processID)
  }

  /// Remove a recorded lost front-switched event.
  @discardableResult
  func removeLostFrontSwitchedEvent(for processID: pid_t) -> Bool {
    lostFrontSwitchedProcessIDs.remove(processID) != nil
  }

  /// Record a focused-window event that arrived before its window was managed.
  func addLostFocusedEvent(for windowID: CGWindowID) {
    guard windowID != 0 else { return }
    lostFocusedWindowIDs.insert(windowID)
  }

  /// Return whether a focused-window event is waiting for a window.
  func containsLostFocusedEvent(for windowID: CGWindowID) -> Bool {
    lostFocusedWindowIDs.contains(windowID)
  }

  /// Return a snapshot of window IDs with lost focused-window events.
  func lostFocusedWindowIDsSnapshot() -> [CGWindowID] {
    Array(lostFocusedWindowIDs)
  }

  /// Remove a recorded lost focused-window event.
  @discardableResult
  func removeLostFocusedEvent(for windowID: CGWindowID) -> Bool {
    lostFocusedWindowIDs.remove(windowID) != nil
  }

  /// Add a managed application.
  func add(application: Application) {
    applicationsByPID[application.processID] = application
  }

  /// Remove a managed application and associated pending event state.
  func remove(application: Application) {
    lostFrontSwitchedProcessIDs.remove(application.processID)
    unresolvedApplicationIDs.remove(application.processID)
    applicationsByPID.removeValue(forKey: application.processID)
  }

  /// Create, observe, and store one managed window for an application.
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

  /// Add all currently accessible windows for an application.
  @discardableResult
  func addWindows(for application: Application) -> [Window] {
    let elements = application.windowElements()
    var windows = [Window]()

    for element in elements {
      guard
        let windowID = AccessibilityClient.shared.optionalWindowID(for: element),
        windowsByID[windowID] == nil
      else {
        continue
      }

      if let window = addWindow(for: application, with: element) {
        windows.append(window)
      }
    }

    return windows
  }

  /// Remove a managed window by ID.
  func remove(by windowID: CGWindowID) {
    lostFocusedWindowIDs.remove(windowID)
    windowsByID.removeValue(forKey: windowID)
  }

  /// Reconcile WindowServer IDs with accessibility window elements for an application.
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

  /// Start managing one observable process and discover its windows.
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

  /// Register windows that already have accessibility elements.
  private func registerAccessibleWindows(
    for application: Application,
    elements: [AXUIElement]
  ) -> Int {
    var resolvedWindowCount = 0

    for element in elements {
      guard let windowID = AccessibilityClient.shared.optionalWindowID(for: element) else {
        continue
      }

      resolvedWindowCount += 1

      if windowsByID[windowID] == nil {
        _ = addWindow(for: application, with: element)
      }
    }

    return resolvedWindowCount
  }

  /// Finish a refresh attempt when all windows are resolved.
  private func finishResolution(for application: Application, mode: WindowDiscoveryMode) -> Bool {
    guard mode == .refreshAttempt else { return false }
    log("all windows resolved \(application)", level: .info)
    unresolvedApplicationIDs.remove(application.processID)
    return true
  }

  /// Attempt to resolve missing windows by creating accessibility elements from remote tokens.
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
        AccessibilityClient.shared.isWindow(element),
        let windowID = AccessibilityClient.shared.optionalWindowID(for: element)
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

  /// Create the private accessibility remote token for a process-local window index.
  private func createRemoteToken(for pid: pid_t, with id: Int) -> CFData {
    var token = Data()

    token.append(contentsOf: withUnsafeBytes(of: pid) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0x636f_636f)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: id) { Data($0) })

    return token as CFData
  }

  /// Update unresolved-application tracking after a discovery pass.
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

/// Identifies whether discovery is initial or a retry for unresolved windows.
private enum WindowDiscoveryMode {
  case initialDiscovery
  case refreshAttempt
}
