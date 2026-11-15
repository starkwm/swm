import AppKit
import ApplicationServices
import CHIServices
import Carbon
import Foundation

@MainActor
public final class Windows {
  nonisolated static func focusedWindowID() -> CGWindowID? {
    guard let processID = WindowServerClient.shared.frontmostProcessID() else {
      return nil
    }

    let accessibility = AccessibilityClient.shared
    return accessibility.focusedWindowID(for: accessibility.applicationElement(for: processID))
  }

  var currentFocusedWindowID: CGWindowID? {
    focusedWindowState.current
  }

  var lastFocusedWindowID: CGWindowID? {
    focusedWindowState.last
  }

  private let workspace: Workspace
  private let isObservable: (Process) -> Bool
  private let makeApplication: (Process) -> Application?
  private let observeApplication: (Application) -> Result<Void, AccessibilityClientError>
  private let accessibleWindows: ((Application) -> [Window])?
  private let discoveryRetryPolicy: DiscoveryRetryPolicy
  private var discoveryRetries = [ObjectIdentifier: Task<Void, Never>]()
  private var discoveryRetryCounts = [ObjectIdentifier: Int]()
  private var mouseEventMonitor: Any?
  private var pendingMouseFocusWindowID: CGWindowID?
  private(set) var focusFollowsMouseMode = FocusFollowsMouseMode.off
  private(set) var focusedWindowState: TrackedState<CGWindowID>
  private var applicationsByPID = [pid_t: Application]()
  private var unresolvedApplicationIDs = Set<pid_t>()
  private var windowsByID = [CGWindowID: Window]()
  private var lostFrontSwitchedProcessIDs = Set<pid_t>()
  private var lostFocusedWindowIDs = Set<CGWindowID>()
  private var remoteWindowScans = [pid_t: RemoteWindowScan]()
  private var ignoredWindowIDsByPID = [pid_t: Set<CGWindowID>]()

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
    accessibleWindows: ((Application) -> [Window])? = nil,
    discoveryRetryPolicy: DiscoveryRetryPolicy = .standard
  ) {
    self.workspace = workspace
    self.isObservable = isObservable ?? workspace.isObservable
    self.makeApplication = makeApplication
    self.observeApplication = observeApplication
    self.accessibleWindows = accessibleWindows
    self.discoveryRetryPolicy = discoveryRetryPolicy
    focusedWindowState = TrackedState(current: focusedWindowID)
  }

  isolated deinit {
    for task in discoveryRetries.values { task.cancel() }
  }

  public func discover(from processes: Processes, onRecovery: @escaping () -> Void) {
    for process in processes.all() {
      if !workspace.isFinishedLaunching(process) {
        guard workspace.observeUntilFinishedLaunching(process) else {
          if process.application == nil {
            retryDiscovery(
              for: process,
              resolveProcess: { processes.find(by: process.psn) },
              retry: { Events.shared.post(.application(.launched(process))) }
            )
          }
          continue
        }
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
    if reconcileWindows(for: application) {
      resetDiscoveryRetries(for: process)
    } else {
      retry()
    }
  }

  func retryDiscovery(
    for process: Process,
    resolveProcess: @escaping () -> Process?,
    retry: @escaping () -> Void
  ) {
    let identity = ObjectIdentifier(process)
    guard !process.terminated, discoveryRetries[identity] == nil else { return }

    let retries = discoveryRetryCounts[identity, default: 0]
    guard let delay = discoveryRetryPolicy.delay(afterRetries: retries) else {
      discoveryRetryCounts.removeValue(forKey: identity)
      log("giving up discovery after \(retries) retries \(process)", level: .warn)
      return
    }

    discoveryRetryCounts[identity] = retries + 1
    discoveryRetries[identity] = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(for: delay)
      } catch { return }
      guard let self else { return }
      discoveryRetries.removeValue(forKey: identity)
      guard !process.terminated, resolveProcess() === process else {
        discoveryRetryCounts.removeValue(forKey: identity)
        return
      }
      retry()
    }
  }

  func resetDiscoveryRetries(for process: Process) {
    discoveryRetryCounts.removeValue(forKey: ObjectIdentifier(process))
  }

  func cancelDiscoveryRetry(for process: Process) {
    resetDiscoveryRetries(for: process)
    discoveryRetries.removeValue(forKey: ObjectIdentifier(process))?.cancel()
  }

  func waitForDiscoveryRetries() async {
    while !discoveryRetries.isEmpty {
      for task in Array(discoveryRetries.values) { await task.value }
    }
  }

  func application(by pid: pid_t) -> Application? {
    applicationsByPID[pid]
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

  func focusedWindowDidChange(to windowID: CGWindowID) {
    guard windowID != 0 else { return }
    pendingMouseFocusWindowID = nil
    focusedWindowState.update(to: windowID)
  }

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

  func refreshWindows() {
    for processID in Array(unresolvedApplicationIDs) {
      guard let application = applicationsByPID[processID] else {
        unresolvedApplicationIDs.remove(processID)
        continue
      }

      refreshWindows(for: application)
    }
  }

  @discardableResult
  func refreshWindows(for application: Application) -> Bool {
    reconcileWindows(for: application)
  }

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

  func addLostFrontSwitchedEvent(for processID: pid_t) {
    lostFrontSwitchedProcessIDs.insert(processID)
  }

  @discardableResult
  func removeLostFrontSwitchedEvent(for processID: pid_t) -> Bool {
    lostFrontSwitchedProcessIDs.remove(processID) != nil
  }

  func addLostFocusedEvent(for windowID: CGWindowID) {
    guard windowID != 0 else { return }
    lostFocusedWindowIDs.insert(windowID)
  }

  func lostFocusedWindowIDsSnapshot() -> [CGWindowID] {
    Array(lostFocusedWindowIDs)
  }

  @discardableResult
  func removeLostFocusedEvent(for windowID: CGWindowID) -> Bool {
    lostFocusedWindowIDs.remove(windowID) != nil
  }

  func replayLostFocusedEvent(for windowID: CGWindowID) {
    guard removeLostFocusedEvent(for: windowID) else { return }
    Events.shared.post(.window(.focused(windowID)))
  }

  func remove(application: Application) {
    lostFrontSwitchedProcessIDs.remove(application.processID)
    unresolvedApplicationIDs.remove(application.processID)
    remoteWindowScans.removeValue(forKey: application.processID)
    ignoredWindowIDsByPID.removeValue(forKey: application.processID)

    applicationsByPID.removeValue(forKey: application.processID)
  }

  @discardableResult
  func addWindow(
    for application: Application,
    with element: AXUIElement,
    id windowID: CGWindowID
  ) -> Window? {
    guard windowID != 0 else { return nil }
    let window = Window(id: windowID, element: element, application: application)

    guard let subrole = window.subrole else { return nil }

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

  func addWindow(with windowID: CGWindowID, for application: Application) -> Window? {
    if let window = windowsByID[windowID] {
      return window
    }

    if let element = AccessibilityClient.shared.focusedWindowElement(for: application.element),
      AccessibilityClient.shared.optionalWindowID(for: element) == windowID,
      let window = addWindow(for: application, with: element, id: windowID)
    {
      return window
    }

    if let element = application.windowElements().first(where: {
      AccessibilityClient.shared.optionalWindowID(for: $0) == windowID
    }) {
      return addWindow(for: application, with: element, id: windowID)
    }

    addWindows(for: application)
    return windowsByID[windowID]
  }

  func addWindows(for application: Application) {
    if let accessibleWindows {
      for window in accessibleWindows(application)
      where window.id != 0 && windowsByID[window.id] == nil {
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

      _ = addWindow(for: application, with: element, id: windowID)
    }
  }

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

  func remove(by windowID: CGWindowID) {
    lostFocusedWindowIDs.remove(windowID)
    windowsByID.removeValue(forKey: windowID)
  }

  private func reconcileWindows(for application: Application) -> Bool {
    let processID = application.processID
    let globalWindowIDs = application.windowIdentifiers()
    addWindows(for: application)
    guard let globalWindowIDs else {
      unresolvedApplicationIDs.insert(processID)
      return false
    }

    let liveWindowIDs = Set(globalWindowIDs)
    let ignoredWindowIDs = ignoredWindowIDsByPID[processID, default: []]
      .intersection(liveWindowIDs)
    ignoredWindowIDsByPID[processID] = ignoredWindowIDs.isEmpty ? nil : ignoredWindowIDs

    guard !unresolvedWindowIDs(in: globalWindowIDs, for: processID).isEmpty else {
      remoteWindowScans.removeValue(forKey: processID)
      unresolvedApplicationIDs.remove(processID)
      return true
    }

    unresolvedApplicationIDs.insert(processID)
    var scan = remoteWindowScans[processID] ?? RemoteWindowScan()
    scan.retainWindows(liveWindowIDs)
    let scannableWindowIDs = scan.scannableWindowIDs(
      unresolvedWindowIDs(in: globalWindowIDs, for: processID)
    )
    if !scannableWindowIDs.isEmpty {
      resolveRemoteWindows(scannableWindowIDs, scan: &scan, for: application)
      let remainingWindowIDs = unresolvedWindowIDs(in: globalWindowIDs, for: processID)
      scan.finishBatch(unresolved: remainingWindowIDs)
      if remainingWindowIDs.isEmpty {
        log("workaround resolved all windows \(application)", level: .info)
        unresolvedApplicationIDs.remove(processID)
      } else if scan.scannableWindowIDs(remainingWindowIDs).isEmpty {
        log("workaround stopped scanning unresolvable windows \(application)", level: .info)
      } else {
        log("workaround failed to resolve all windows \(application)", level: .info)
      }
      if scan.scannableWindowIDs(remainingWindowIDs).isEmpty { scan.restartCycle() }
    }
    remoteWindowScans[processID] = scan
    return true
  }

  private func unresolvedWindowIDs(
    in globalWindowIDs: [CGWindowID],
    for processID: pid_t
  ) -> [CGWindowID] {
    let ignoredWindowIDs = ignoredWindowIDsByPID[processID, default: []]
    return globalWindowIDs.filter { windowsByID[$0] == nil && !ignoredWindowIDs.contains($0) }
  }

  private func resolveRemoteWindows(
    _ windowIDs: [CGWindowID],
    scan: inout RemoteWindowScan,
    for application: Application
  ) {
    log(
      "application has windows that are not resolved, attempting workaround \(application)",
      level: .info
    )

    var unresolvedWindowIDs = Set(windowIDs)
    let tokenIDs = scan.nextBatch(for: windowIDs)

    log(
      "scanning remote window tokens \(tokenIDs.lowerBound)...\(tokenIDs.upperBound) for \(application)"
    )

    for id in tokenIDs {
      guard !unresolvedWindowIDs.isEmpty else { break }

      let token = createRemoteToken(for: application.processID, with: id)

      guard
        let element = _AXUIElementCreateWithRemoteToken(token),
        AccessibilityClient.shared.isWindow(element),
        let windowID = AccessibilityClient.shared.optionalWindowID(for: element),
        unresolvedWindowIDs.contains(windowID)
      else {
        continue
      }

      guard addWindow(for: application, with: element, id: windowID) != nil else {
        if ignoredWindowIDsByPID[application.processID]?.contains(windowID) == true {
          unresolvedWindowIDs.remove(windowID)
        }
        continue
      }

      unresolvedWindowIDs.remove(windowID)
      log("resolved window \(windowID) for \(application)")
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
}
