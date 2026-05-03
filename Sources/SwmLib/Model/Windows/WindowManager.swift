import ApplicationServices
import Carbon
import Foundation

public final class WindowManager {
  public static let shared = WindowManager()

  private let workspace: Workspace
  private let resolver = RemoteWindowResolver()

  private var applicationsByPID = [pid_t: Application]()
  private var unresolvedApplicationIDs = Set<pid_t>()
  private var windowsByID = [CGWindowID: Window]()

  init(
    workspace: Workspace = Workspace.shared
  ) {
    self.workspace = workspace
  }

  public func start(processes: [Process]) {
    for process in processes {
      startManaging(process)
    }
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

  public func application(by pid: pid_t) -> Application? {
    applicationsByPID[pid]
  }

  public func application(by name: String) -> Application? {
    applicationsByPID.values.first { $0.name == name }
  }

  public func allApplications() -> [Application] {
    Array(applicationsByPID.values)
  }

  public func window(by id: CGWindowID) -> Window? {
    windowsByID[id]
  }

  public func allWindows(for application: Application) -> [Window] {
    windowsByID.values.filter { $0.application == application }
  }

  public func allWindows() -> [Window] {
    Array(windowsByID.values)
  }

  public func refreshWindows() {
    for processID in Array(unresolvedApplicationIDs) {
      guard let application = applicationsByPID[processID] else {
        unresolvedApplicationIDs.remove(processID)
        continue
      }

      refreshWindows(for: application)
    }
  }

  public func refreshWindows(for application: Application) {
    guard unresolvedApplicationIDs.contains(application.processID) else { return }
    log("application has windows that are not yet resolved \(application)", level: .info)
    _ = reconcileWindows(for: application, mode: .refreshAttempt)
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

    resolver.resolve(
      unresolvedWindowIDs: &unresolvedWindowIDs,
      for: application,
      addWindow: { [weak self] element in
        guard let self else { return }
        _ = self.addWindow(for: application, with: element)
      }
    )
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

private final class RemoteWindowResolver {
  func resolve(
    unresolvedWindowIDs: inout [CGWindowID],
    for application: Application,
    addWindow: (AXUIElement) -> Void
  ) {
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
        addWindow(element)
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
}
