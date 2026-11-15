import AppKit
import Synchronization

@MainActor
public final class Workspace: NSObject {
  private nonisolated let observationContexts = Mutex<[UInt: ProcessObservationToken]>([:])

  private let postEvent: (RuntimeEvent) -> Void

  private let activationPolicyObservations = ProcessObservationRegistry(
    kind: .activationPolicy
  )
  private let finishedLaunchingObservations = ProcessObservationRegistry(
    kind: .finishedLaunching
  )

  public override convenience init() {
    self.init(postEvent: { Events.shared.post($0) })
  }

  init(postEvent: @escaping (RuntimeEvent) -> Void) {
    self.postEvent = postEvent
    super.init()
  }

  public func observe() {
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(activeSpaceDidChange(_:)),
      name: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil
    )

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(activeDisplayDidChange(_:)),
      name: .activeDisplayDidChange,
      object: nil
    )
  }

  public nonisolated override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    guard let context else { return }

    guard let token = observationContexts.withLock({ $0[UInt(bitPattern: context)] }) else {
      return
    }

    let rawPolicy = change?[.newKey] as? Int
    let finishedLaunching = change?[.newKey] as? Bool
    DispatchQueue.main.async { [self, token] in
      let process = token.process
      guard let registry = registry(for: keyPath), registry.contains(token),
        !process.terminated,
        registry.kind.shouldRelaunch(
          process: process,
          rawPolicy: rawPolicy,
          finishedLaunching: finishedLaunching
        )
      else { return }
      unobserve(process, registry: registry)
      postEvent(.application(.launched(process)))
    }
  }

  func isObservable(_ process: Process) -> Bool {
    guard let application = process.resolveApplication() else {
      process.policy = .prohibited
      return false
    }

    process.policy = application.activationPolicy

    return process.policy == .regular || process.policy == .accessory
  }

  func observeActivationPolicy(_ process: Process) {
    observe(process, registry: activationPolicyObservations)
  }

  func unobserveActivationPolicy(_ process: Process) {
    unobserve(process, registry: activationPolicyObservations)
  }

  func isFinishedLaunching(_ process: Process) -> Bool {
    guard let application = process.resolveApplication() else { return false }

    return application.isFinishedLaunching
  }

  func observeFinishedLaunching(_ process: Process) {
    observe(process, registry: finishedLaunchingObservations)
  }

  func unobserveFinishedLaunching(_ process: Process) {
    unobserve(process, registry: finishedLaunchingObservations)
  }

  func observeUntilFinishedLaunching(_ process: Process) -> Bool {
    observeFinishedLaunching(process)
    guard isFinishedLaunching(process) else { return false }
    unobserveFinishedLaunching(process)
    return true
  }

  @objc
  func activeSpaceDidChange(_: Notification) {
    postEvent(.space(Spaces.active().map(SpaceEvent.changed) ?? .unavailable))
  }

  @objc
  func activeDisplayDidChange(_: Notification) {
    postEvent(.display(.changed))
  }

  private func observe(_ process: Process, registry: ProcessObservationRegistry) {
    guard let application = process.resolveApplication() else { return }

    guard let token = registry.register(process, application: application) else { return }
    observationContexts.withLock { $0[token.contextID] = token }

    token.application.addObserver(
      self,
      forKeyPath: token.keyPath,
      options: [.initial, .new],
      context: token.context
    )
  }

  private func unobserve(_ process: Process, registry: ProcessObservationRegistry) {
    guard let token = registry.unregister(process) else { return }
    _ = observationContexts.withLock { $0.removeValue(forKey: token.contextID) }

    token.application.removeObserver(self, forKeyPath: token.keyPath, context: token.context)
  }

  private func registry(for keyPath: String?) -> ProcessObservationRegistry? {
    switch keyPath {
    case activationPolicyObservations.kind.keyPath:
      activationPolicyObservations
    case finishedLaunchingObservations.kind.keyPath:
      finishedLaunchingObservations
    default:
      nil
    }
  }
}

extension Notification.Name {
  fileprivate static let activeDisplayDidChange = Notification.Name(
    "NSWorkspaceActiveDisplayDidChangeNotification"
  )
}

private final class ProcessObservationToken: Sendable {
  private static let nextContextID = Mutex<UInt>(1)

  private static func makeContextID() -> UInt {
    nextContextID.withLock { value in
      let result = value
      value += 1
      return result
    }
  }

  let contextID = makeContextID()
  let application: NSRunningApplication
  let process: Process
  let keyPath: String
  let processID: UInt32

  var context: UnsafeMutableRawPointer {
    UnsafeMutableRawPointer(bitPattern: contextID)!
  }

  init(application: NSRunningApplication, process: Process, keyPath: String, processID: UInt32) {
    self.application = application
    self.process = process
    self.keyPath = keyPath
    self.processID = processID
  }
}

@MainActor
private enum ProcessObservationKind {
  case activationPolicy

  case finishedLaunching

  var keyPath: String {
    switch self {
    case .activationPolicy:
      "activationPolicy"
    case .finishedLaunching:
      "finishedLaunching"
    }
  }

  func shouldRelaunch(process: Process, rawPolicy: Int?, finishedLaunching: Bool?) -> Bool {
    switch self {
    case .activationPolicy:
      guard
        let raw = rawPolicy,
        let result = NSApplication.ActivationPolicy(rawValue: raw)
      else { return false }

      return result != process.policy
    case .finishedLaunching:
      guard let result = finishedLaunching else { return false }
      return result
    }
  }
}

@MainActor
private final class ProcessObservationRegistry {
  let kind: ProcessObservationKind

  private var tokens = [UInt32: ProcessObservationToken]()

  init(kind: ProcessObservationKind) {
    self.kind = kind
  }

  func register(_ process: Process, application: NSRunningApplication) -> ProcessObservationToken? {
    guard tokens[process.psn.lowLongOfPSN] == nil else { return nil }

    let token = ProcessObservationToken(
      application: application,
      process: process,
      keyPath: kind.keyPath,
      processID: process.psn.lowLongOfPSN
    )

    tokens[token.processID] = token

    return token
  }

  func contains(_ token: ProcessObservationToken) -> Bool {
    tokens[token.processID] === token
  }

  func unregister(_ process: Process) -> ProcessObservationToken? {
    tokens.removeValue(forKey: process.psn.lowLongOfPSN)
  }
}
