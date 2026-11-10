import AppKit
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

    let accessibility = AccessibilityClient.shared
    return accessibility.focusedWindowID(for: accessibility.applicationElement(for: processID))
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
  private let isObservable: (Process) -> Bool
  private let makeApplication: (Process) -> Application?
  private let observeApplication: (Application) -> Result<Void, AccessibilityClientError>
  private let accessibleWindows: ((Application) -> [Window])?
  private var discoveryRetries = [ObjectIdentifier: Task<Void, Never>]()
  private var mouseEventMonitor: Any?
  private var pendingMouseFocusWindowID: CGWindowID?
  private(set) var focusFollowsMouseMode = FocusFollowsMouseMode.off
  private(set) var focusedWindowState: TrackedState<CGWindowID>
  private var applicationsByPID = [pid_t: Application]()
  private var unresolvedApplicationIDs = Set<pid_t>()
  private var windowsByID = [CGWindowID: Window]()
  private var lostFrontSwitchedProcessIDs = Set<pid_t>()
  private var lostFocusedWindowIDs = Set<CGWindowID>()
  private var remoteTokenCursors = [pid_t: WindowDiscoveryCursor]()
  private var ignoredWindowIDsByPID = [pid_t: Set<CGWindowID>]()

  /// Create the window service for a workspace.
  public convenience init(workspace: Workspace) {
    self.init(workspace: workspace, focusedWindowID: Self.focusedWindowID())
  }

  init(
    workspace: Workspace,
    focusedWindowID: CGWindowID?,
    isObservable: ((Process) -> Bool)? = nil,
    makeApplication: @escaping (Process) -> Application? = { Application(for: $0) },
    observeApplication: @escaping (Application) -> Result<Void, AccessibilityClientError> = {
      $0.observe()
    },
    accessibleWindows: ((Application) -> [Window])? = nil
  ) {
    self.workspace = workspace
    self.isObservable = isObservable ?? workspace.isObservable
    self.makeApplication = makeApplication
    self.observeApplication = observeApplication
    self.accessibleWindows = accessibleWindows
    focusedWindowState = TrackedState(current: focusedWindowID)
  }

  isolated deinit {
    for task in discoveryRetries.values { task.cancel() }
  }

  /// Discover and observe windows from all supplied processes.
  public func discover(from processes: Processes, onRecovery: @escaping () -> Void) {
    for process in processes.all() {
      if !workspace.isFinishedLaunching(process) {
        guard workspace.observeUntilFinishedLaunching(process) else { continue }
      }
      discover(process, resolveProcess: { processes.find(by: process.psn) }, onRecovery: onRecovery)
    }
  }

  func discover(
    _ process: Process,
    resolveProcess: @escaping () -> Process?,
    onRecovery: @escaping () -> Void
  ) {
    guard !process.terminated else { return }
    let retry = { [weak self] in
      self?.retryDiscovery(for: process, resolveProcess: resolveProcess) { [weak self] in
        self?.discover(process, resolveProcess: resolveProcess, onRecovery: onRecovery)
        onRecovery()
      }
    }
    guard let application = manage(process, retryObservation: { retry() }) else { return }
    if !reconcileWindows(for: application) { retry() }
  }

  /// Share launch and startup retries, rejecting late work for a replaced process.
  func retryDiscovery(
    for process: Process,
    resolveProcess: @escaping () -> Process?,
    retry: @escaping () -> Void
  ) {
    let identity = ObjectIdentifier(process)
    guard !process.terminated, discoveryRetries[identity] == nil else { return }
    discoveryRetries[identity] = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(100))
      } catch { return }
      guard let self else { return }
      discoveryRetries.removeValue(forKey: identity)
      guard !process.terminated, resolveProcess() === process else { return }
      retry()
    }
  }

  func cancelDiscoveryRetry(for process: Process) {
    discoveryRetries.removeValue(forKey: ObjectIdentifier(process))?.cancel()
  }

  func waitForDiscoveryRetries() async {
    while !discoveryRetries.isEmpty {
      for task in Array(discoveryRetries.values) { await task.value }
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

  /// Resolve the closest non-minimized window on the currently visible Spaces.
  func directionalWindow(
    from sourceWindow: Window,
    in direction: CardinalDirection,
    spaces: Spaces,
    isEligible: (CGWindowID) -> Bool = { _ in true }
  ) -> Window? {
    let candidateWindows = allWindows()
    guard let topology = spaces.snapshotTopology(for: candidateWindows.map(\.id)) else {
      return nil
    }
    let visibleSpaceIDs = Set(topology.visibleSpaceIDByDisplayID.values)
    let framesByWindowID = Dictionary(
      uniqueKeysWithValues: candidateWindows.compactMap { window -> (CGWindowID, CGRect)? in
        guard !window.isMinimized, isEligible(window.id) else { return nil }
        guard
          let spaceIDs = topology.spaceIDsByWindowID[window.id],
          !spaceIDs.isDisjoint(with: visibleSpaceIDs),
          let frame = window.frame()
        else {
          return nil
        }
        return (window.id, frame)
      }
    )

    guard let windowID = direction.neighbor(of: sourceWindow.id, in: framesByWindowID) else {
      return nil
    }
    return window(by: windowID)
  }

  /// Update tracked focused-window state.
  func focusedWindowDidChange(to windowID: CGWindowID) {
    guard windowID != 0 else { return }
    pendingMouseFocusWindowID = nil
    focusedWindowState.update(to: windowID)
  }

  /// Select how pointer movement focuses managed windows.
  func setFocusFollowsMouseMode(_ mode: FocusFollowsMouseMode) {
    focusFollowsMouseMode = mode

    if mode != .off {
      guard mouseEventMonitor == nil else { return }

      mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) {
        [weak self] event in
        guard let location = event.cgEvent?.location else { return }

        Task { @MainActor [weak self] in
          self?.focusWindow(at: location)
        }
      }
    } else {
      pendingMouseFocusWindowID = nil
      guard let mouseEventMonitor else { return }
      NSEvent.removeMonitor(mouseEventMonitor)
      self.mouseEventMonitor = nil
    }
  }

  /// Focus the frontmost managed window beneath a global pointer location.
  func focusWindow(at point: CGPoint) {
    guard let windowID = WindowServerClient.shared.frontmostWindowID(at: point) else { return }
    guard windowID != currentFocusedWindowID else { return }
    guard windowID != pendingMouseFocusWindowID else { return }
    guard let window = window(by: windowID), !window.isMinimized else { return }

    let focused: Bool
    switch focusFollowsMouseMode {
    case .off:
      return
    case .autofocus:
      focused = window.focusWithoutRaise(from: currentFocusedWindowID.flatMap(window(by:)))
    case .autoraise:
      focused = window.focus()
    }

    if focused {
      pendingMouseFocusWindowID = windowID
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

  /// Rediscover windows, including windows lost after an earlier successful discovery.
  @discardableResult
  func refreshWindows(for application: Application) -> Bool {
    reconcileWindows(for: application)
  }

  /// Recover an unknown focused window without waiting for another creation notification.
  func recoverFocusedWindow(with windowID: CGWindowID) -> Window? {
    guard windowID != 0 else { return nil }
    if let window = windowsByID[windowID] { return window }

    guard
      let processID = WindowServerClient.shared.frontmostProcessID(),
      let application = applicationsByPID[processID],
      application.focusedWindowID() == windowID
    else { return nil }

    if let window = addWindow(with: windowID, for: application) {
      return window
    }

    refreshWindows(for: application)
    return windowsByID[windowID]
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

  /// Post a recorded lost focused-window event again and remove it from the record.
  func replayLostFocusedEvent(for windowID: CGWindowID) {
    guard removeLostFocusedEvent(for: windowID) else { return }
    Events.shared.post(.window(.focused(windowID)))
  }

  /// Remove a managed application and associated pending event state.
  func remove(application: Application) {
    lostFrontSwitchedProcessIDs.remove(application.processID)
    unresolvedApplicationIDs.remove(application.processID)
    remoteTokenCursors.removeValue(forKey: application.processID)
    ignoredWindowIDsByPID.removeValue(forKey: application.processID)

    applicationsByPID.removeValue(forKey: application.processID)
  }

  /// Create, observe, and store one managed window for an application.
  @discardableResult
  func addWindow(for application: Application, with element: AXUIElement) -> Window? {
    let window = Window(with: element, for: application)

    guard let subrole = window.subrole else { return nil }

    // Accessory processes own menu bar strips and panels; keep only their real windows.
    guard !application.isAccessory || subrole == "AXStandardWindow" else {
      ignoredWindowIDsByPID[application.processID, default: []].insert(window.id)
      return nil
    }

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

    // Some apps expose their focused window before including it in AXWindows.
    if let element = AccessibilityClient.shared.focusedWindowElement(for: application.element),
      AccessibilityClient.shared.optionalWindowID(for: element) == windowID,
      let window = addWindow(for: application, with: element)
    {
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
    if let accessibleWindows {
      for window in accessibleWindows(application) where windowsByID[window.id] == nil {
        windowsByID[window.id] = window
      }
      return
    }
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
    guard !process.terminated else { return nil }
    if let application = applicationsByPID[process.pid] {
      guard WindowServerClient.sameProcess(application.processSerialNumber, process.psn) else {
        return nil
      }
      return application
    }

    guard isObservable(process) else {
      log("application is not observable \(process)")
      workspace.observeActivationPolicy(process)
      return nil
    }

    guard let application = makeApplication(process) else {
      log("could not create application for process \(process)", level: .info)
      return nil
    }

    switch observeApplication(application) {
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
  private func reconcileWindows(for application: Application) -> Bool {
    let globalWindowIDs = application.windowIdentifiers()
    addWindows(for: application)
    guard let globalWindowIDs else {
      unresolvedApplicationIDs.insert(application.processID)
      return false
    }

    // Forget ignored windows that no longer exist, and do not rescan the rest.
    let ignoredWindowIDs = ignoredWindowIDsByPID[application.processID, default: []]
      .intersection(globalWindowIDs)
    ignoredWindowIDsByPID[application.processID] =
      ignoredWindowIDs.isEmpty ? nil : ignoredWindowIDs

    var unresolvedWindowIDs = globalWindowIDs.filter {
      windowsByID[$0] == nil && !ignoredWindowIDs.contains($0)
    }

    guard !unresolvedWindowIDs.isEmpty else {
      remoteTokenCursors.removeValue(forKey: application.processID)
      unresolvedApplicationIDs.remove(application.processID)
      return true
    }

    resolveRemoteWindows(&unresolvedWindowIDs, for: application)

    if unresolvedWindowIDs.isEmpty {
      log("workaround resolved all windows \(application)", level: .info)
      unresolvedApplicationIDs.remove(application.processID)
    } else {
      log("workaround failed to resolve all windows \(application)", level: .info)
      unresolvedApplicationIDs.insert(application.processID)
    }
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

    var cursor = remoteTokenCursors[application.processID] ?? WindowDiscoveryCursor()
    let tokenIDs = cursor.nextBatch()
    remoteTokenCursors[application.processID] = cursor

    log(
      "scanning remote window tokens \(tokenIDs.lowerBound)...\(tokenIDs.upperBound) for \(application)"
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
      guard addWindow(for: application, with: element) != nil else {
        if ignoredWindowIDsByPID[application.processID]?.contains(windowID) == true {
          unresolvedWindowIDs.remove(at: index)
        }
        continue
      }

      unresolvedWindowIDs.remove(at: index)
      log("resolved window \(windowID) for \(application)")
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
}
