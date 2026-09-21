import AppKit
import Synchronization

/// Bridges AppKit workspace notifications and process KVO into runtime events.
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

  /// Create a workspace observer for active space and display changes.
  public override convenience init() {
    self.init(postEvent: { Events.shared.post($0) })
  }

  init(postEvent: @escaping (RuntimeEvent) -> Void) {
    self.postEvent = postEvent
    super.init()

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

  /// Handle process KVO updates that make a process ready to manage.
  public nonisolated override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    guard let context else { return }

    // Contexts are never dereferenced. A retained lookup also makes callbacks
    // racing with observer removal safe, even when KVO delivers off the main thread.
    guard let token = observationContexts.withLock({ $0[UInt(bitPattern: context)] }) else {
      return
    }

    // KVO runs on the notifying thread. Copy only scalar change data before
    // queueing work; all process and registry access belongs to the main actor.
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

  /// Return whether a process is currently observable as a regular application.
  func isObservable(_ process: Process) -> Bool {
    guard let application = process.application else {
      process.policy = .prohibited
      return false
    }

    process.policy = application.activationPolicy

    return process.policy == .regular
  }

  /// Observe a process until its activation policy changes.
  func observeActivationPolicy(_ process: Process) {
    observe(process, registry: activationPolicyObservations)
  }

  /// Stop observing a process activation policy.
  func unobserveActivationPolicy(_ process: Process) {
    unobserve(process, registry: activationPolicyObservations)
  }

  /// Return whether a process application has finished launching.
  func isFinishedLaunching(_ process: Process) -> Bool {
    guard let application = process.application else { return false }

    return application.isFinishedLaunching
  }

  /// Observe a process until its application finishes launching.
  func observeFinishedLaunching(_ process: Process) {
    observe(process, registry: finishedLaunchingObservations)
  }

  /// Stop observing a process finished-launching state.
  func unobserveFinishedLaunching(_ process: Process) {
    unobserve(process, registry: finishedLaunchingObservations)
  }

  /// Publish an active-space changed event.
  @objc
  func activeSpaceDidChange(_: Notification) {
    Events.shared.post(.space(.changed(Spaces.active())))
  }

  /// Publish an active-display changed event.
  @objc
  func activeDisplayDidChange(_: Notification) {
    Events.shared.post(.display(.changed))
  }

  /// Start observing one KVO-backed process readiness condition.
  private func observe(_ process: Process, registry: ProcessObservationRegistry) {
    guard let application = process.application else { return }

    guard let token = registry.register(process, application: application) else { return }
    observationContexts.withLock { $0[token.contextID] = token }

    token.application.addObserver(
      self,
      forKeyPath: token.keyPath,
      options: [.initial, .new],
      context: token.context
    )
  }

  /// Stop observing one KVO-backed process readiness condition.
  private func unobserve(_ process: Process, registry: ProcessObservationRegistry) {
    guard let token = registry.unregister(process) else { return }
    _ = observationContexts.withLock { $0.removeValue(forKey: token.contextID) }

    token.application.removeObserver(self, forKeyPath: token.keyPath, context: token.context)
  }

  /// Return the observation registry that owns a KVO key path.
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
  /// AppKit notification emitted when the active display changes.
  fileprivate static let activeDisplayDidChange = Notification.Name(
    "NSWorkspaceActiveDisplayDidChangeNotification"
  )
}

/// KVO observation token for one process readiness condition.
private final class ProcessObservationToken: Sendable {
  private static let nextContextID = Mutex<UInt>(1)

  // Never reuse a context identifier: a late callback must not resolve a new observation.
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

/// Process readiness condition that can trigger application management.
@MainActor
private enum ProcessObservationKind {
  /// Wait for the process activation policy to change.
  case activationPolicy

  /// Wait for the app to finish launching.
  case finishedLaunching

  /// KVO key path for the condition.
  var keyPath: String {
    switch self {
    case .activationPolicy:
      "activationPolicy"
    case .finishedLaunching:
      "finishedLaunching"
    }
  }

  /// Return whether a KVO change means the process should be treated as launched.
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

/// Tracks active KVO observations for one process readiness condition.
@MainActor
private final class ProcessObservationRegistry {
  /// Readiness condition represented by this registry.
  let kind: ProcessObservationKind

  private var tokens = [UInt32: ProcessObservationToken]()

  /// Create a registry for one readiness condition.
  init(kind: ProcessObservationKind) {
    self.kind = kind
  }

  /// Register a new token, or return nil when the process is already observed.
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

  /// Remove and return an observation token for a process.
  func unregister(_ process: Process) -> ProcessObservationToken? {
    tokens.removeValue(forKey: process.psn.lowLongOfPSN)
  }
}
