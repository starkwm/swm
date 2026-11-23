import AppKit
import ApplicationServices
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

  let workspace: Workspace
  let discoveryRetryPolicy: DiscoveryRetryPolicy
  var discoveryRetries = [ObjectIdentifier: Task<Void, Never>]()
  var discoveryRetryCounts = [ObjectIdentifier: Int]()
  var applicationsByPID = [pid_t: Application]()
  var unresolvedApplicationIDs = Set<pid_t>()
  var windowsByID = [CGWindowID: Window]()
  var remoteWindowScans = [pid_t: RemoteWindowScan]()
  var ignoredWindowIDsByPID = [pid_t: Set<CGWindowID>]()

  private let isObservable: (Process) -> Bool
  private let makeApplication: (Process) -> Application?
  private let observeApplication: (Application) -> Result<Void, AccessibilityClientError>
  private let accessibleWindows: ((Application) -> [Window])?
  private var mouseEventMonitor: Any?
  private var pendingMouseFocusWindowID: CGWindowID?
  private(set) var focusFollowsMouseMode = FocusFollowsMouseMode.off
  private(set) var focusedWindowState: TrackedState<CGWindowID>
  private var lostFrontSwitchedProcessIDs = Set<pid_t>()
  private var lostFocusedWindowIDs = Set<CGWindowID>()

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
}
