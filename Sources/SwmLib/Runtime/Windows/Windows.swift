import ApplicationServices
import Carbon
import Foundation

/// Tracks observable applications, managed windows, and focus history.
@MainActor
public final class Windows {
  /// Resolve the currently focused window ID from the frontmost process.
  nonisolated static func focusedWindowID() -> CGWindowID? {
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

  /// Tracked ID of the current focused window.
  var currentFocusedWindowID: CGWindowID? {
    focusedWindowState.current
  }

  /// Tracked ID of the previously focused window.
  var lastFocusedWindowID: CGWindowID? {
    focusedWindowState.last
  }

  private let workspace: Workspace
  private var focusedWindowState: TrackedState<CGWindowID>
  private var applicationsByPID = [pid_t: Application]()
  private var unresolvedApplicationIDs = Set<pid_t>()
  private var windowsByID = [CGWindowID: Window]()
  private var lostFrontSwitchedProcessIDs = Set<pid_t>()
  private var lostFocusedWindowIDs = Set<CGWindowID>()
  private var remoteTokenCursors = [pid_t: WindowDiscoveryCursor]()

  /// Create a window manager for a workspace.
  public init(workspace: Workspace) {
    self.workspace = workspace
    focusedWindowState = TrackedState(current: Self.focusedWindowID())
  }

  /// Start managing all supplied processes.
  public func start(processes: [Process]) {
    for process in processes {
      guard let application = manage(process) else { continue }
      reconcileWindows(for: application, mode: .initialDiscovery)
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

  /// Return all managed windows owned by an application.
  func allWindows(for application: Application) -> [Window] {
    windowsByID.values.filter { $0.application == application }
  }

  /// Return all managed windows.
  func allWindows() -> [Window] {
    Array(windowsByID.values)
  }

  /// Update tracked focused-window state.
  func focusedWindowDidChange(to windowID: CGWindowID) {
    guard windowID != 0 else { return }
    focusedWindowState.update(to: windowID)
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
    reconcileWindows(for: application, mode: .refreshAttempt)
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

  /// Return a snapshot of window IDs with lost focused-window events.
  func lostFocusedWindowIDsSnapshot() -> [CGWindowID] {
    Array(lostFocusedWindowIDs)
  }

  /// Remove a recorded lost focused-window event.
  @discardableResult
  func removeLostFocusedEvent(for windowID: CGWindowID) -> Bool {
    lostFocusedWindowIDs.remove(windowID) != nil
  }

  /// Remove a managed application and associated pending event state.
  func remove(application: Application) {
    lostFrontSwitchedProcessIDs.remove(application.processID)
    unresolvedApplicationIDs.remove(application.processID)
    remoteTokenCursors.removeValue(forKey: application.processID)

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

  /// Find and add one window by ID from an application's accessibility elements.
  func addWindow(with windowID: CGWindowID, for application: Application) -> Window? {
    if let window = windowsByID[windowID] {
      return window
    }

    if let element = application.windowElements().first(where: {
      AccessibilityClient.shared.optionalWindowID(for: $0) == windowID
    }) {
      return addWindow(for: application, with: element)
    }

    addWindows(for: application)
    return windowsByID[windowID]
  }

  /// Add all currently accessible windows for an application.
  func addWindows(for application: Application) {
    for element in application.windowElements() {
      guard
        let windowID = AccessibilityClient.shared.optionalWindowID(for: element),
        windowsByID[windowID] == nil
      else {
        continue
      }

      _ = addWindow(for: application, with: element)
    }
  }

  /// Manage one observable process and register its application observer.
  func manage(_ process: Process, retryObservation: (() -> Void)? = nil) -> Application? {
    guard applicationsByPID[process.pid] == nil else { return nil }

    guard workspace.isObservable(process) else {
      log("application is not observable \(process)", level: .info)
      workspace.observeActivationPolicy(process)
      return nil
    }

    guard let application = Application(for: process) else {
      log("could not create application for process \(process)", level: .info)
      return nil
    }

    switch application.observe() {
    case .success:
      break
    case .failure(let error):
      log(
        "could not observe application \(application): \(error)",
        level: application.retryObserving ? .info : .warn
      )
      application.unobserve()

      if application.retryObserving {
        retryObservation?()
      }

      return nil
    }

    applicationsByPID[application.processID] = application
    return application
  }

  /// Remove a managed window by ID.
  func remove(by windowID: CGWindowID) {
    lostFocusedWindowIDs.remove(windowID)
    windowsByID.removeValue(forKey: windowID)
  }

  /// Reconcile WindowServer IDs with accessibility window elements for an application.
  private func reconcileWindows(
    for application: Application,
    mode: WindowDiscoveryMode
  ) {
    let globalWindowIDs = application.windowIdentifiers()
    addWindows(for: application)

    var unresolvedWindowIDs = globalWindowIDs.filter { windowsByID[$0] == nil }

    guard !unresolvedWindowIDs.isEmpty else {
      remoteTokenCursors.removeValue(forKey: application.processID)
      finishResolution(for: application, mode: mode)
      return
    }

    resolveRemoteWindows(&unresolvedWindowIDs, for: application)

    updateRefreshTracking(
      for: application,
      unresolvedWindowIDs: unresolvedWindowIDs,
      mode: mode
    )
  }

  /// Finish a refresh attempt when all windows are resolved.
  private func finishResolution(for application: Application, mode: WindowDiscoveryMode) {
    guard mode == .refreshAttempt else { return }
    log("all windows resolved \(application)", level: .info)
    unresolvedApplicationIDs.remove(application.processID)
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

    var cursor = remoteTokenCursors[application.processID] ?? WindowDiscoveryCursor()
    let tokenIDs = cursor.nextBatch()
    remoteTokenCursors[application.processID] = cursor

    log(
      "scanning remote window tokens \(tokenIDs.lowerBound)...\(tokenIDs.upperBound) for \(application)",
      level: .info
    )

    for id in tokenIDs {
      guard !unresolvedWindowIDs.isEmpty else { break }

      let token = createRemoteToken(for: application.processID, with: id)

      guard
        let element = _AXUIElementCreateWithRemoteToken(token)?.takeRetainedValue(),
        AccessibilityClient.shared.isWindow(element),
        let windowID = AccessibilityClient.shared.optionalWindowID(for: element)
      else {
        continue
      }

      guard let index = unresolvedWindowIDs.firstIndex(of: windowID) else { continue }
      guard addWindow(for: application, with: element) != nil else { continue }

      unresolvedWindowIDs.remove(at: index)
      log("resolved window \(windowID) for \(application)", level: .info)
    }

    if unresolvedWindowIDs.isEmpty {
      remoteTokenCursors.removeValue(forKey: application.processID)
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
  ) {
    switch mode {
    case .initialDiscovery:
      if !unresolvedWindowIDs.isEmpty {
        log("workaround failed to resolve all windows \(application)", level: .info)
        unresolvedApplicationIDs.insert(application.processID)
      }

    case .refreshAttempt:
      if unresolvedWindowIDs.isEmpty {
        log("workaround successfully resolved all windows \(application)", level: .info)
        unresolvedApplicationIDs.remove(application.processID)
      }
    }
  }
}

/// Identifies whether discovery is initial or a retry for unresolved windows.
private enum WindowDiscoveryMode {
  case initialDiscovery
  case refreshAttempt
}
