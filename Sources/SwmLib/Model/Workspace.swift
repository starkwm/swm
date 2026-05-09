import AppKit

/// Bridges AppKit workspace notifications and process KVO into runtime events.
public final class Workspace: NSObject {
  private let activationPolicyObservations = ProcessObservationRegistry(
    kind: .activationPolicy
  )
  private let finishedLaunchingObservations = ProcessObservationRegistry(
    kind: .finishedLaunching
  )

  /// Create a workspace observer for active space and display changes.
  public override init() {
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
  public override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    guard let context else { return }

    let process = Unmanaged<Process>.fromOpaque(context).takeUnretainedValue()

    guard let registry = registry(for: keyPath) else { return }
    guard registry.kind.shouldRelaunch(process: process, change: change) else { return }

    unobserve(process, registry: registry)
    EventManager.shared.post(.application(.launched(process)))
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
    EventManager.shared.post(.space(.changed(SpaceManager.active())))
  }

  /// Publish an active-display changed event.
  @objc
  func activeDisplayDidChange(_: Notification) {
    EventManager.shared.post(.display(.changed))
  }

  /// Start observing one KVO-backed process readiness condition.
  private func observe(_ process: Process, registry: ProcessObservationRegistry) {
    guard process.application != nil else { return }

    let token = registry.register(process)

    process.application?.addObserver(
      self,
      forKeyPath: token.keyPath,
      options: [.initial, .new],
      context: token.context
    )
  }

  /// Stop observing one KVO-backed process readiness condition.
  private func unobserve(_ process: Process, registry: ProcessObservationRegistry) {
    guard process.application != nil else { return }
    guard let token = registry.unregister(process) else { return }

    process.application?.removeObserver(self, forKeyPath: token.keyPath, context: token.context)
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

extension Workspace: @unchecked Sendable {}

extension Notification.Name {
  /// AppKit notification emitted when the active display changes.
  fileprivate static let activeDisplayDidChange = Notification.Name(
    "NSWorkspaceActiveDisplayDidChangeNotification"
  )
}

/// KVO observation token for one process readiness condition.
private struct ProcessObservationToken {
  /// Observed KVO key path.
  let keyPath: String

  /// Unmanaged process pointer passed as KVO context.
  let context: UnsafeMutableRawPointer?

  /// Stable process key used for registry lookup.
  let processID: UInt32
}

/// Process readiness condition that can trigger application management.
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
  func shouldRelaunch(process: Process, change: [NSKeyValueChangeKey: Any]?) -> Bool {
    switch self {
    case .activationPolicy:
      guard
        let raw = change?[.newKey] as? Int,
        let result = NSApplication.ActivationPolicy(rawValue: raw)
      else { return false }

      return result != process.policy
    case .finishedLaunching:
      guard let result = change?[.newKey] as? Bool else { return false }
      return result
    }
  }
}

/// Tracks active KVO observations for one process readiness condition.
private final class ProcessObservationRegistry {
  /// Readiness condition represented by this registry.
  let kind: ProcessObservationKind

  private var tokens = [UInt32: ProcessObservationToken]()

  /// Create a registry for one readiness condition.
  init(kind: ProcessObservationKind) {
    self.kind = kind
  }

  /// Register or return the existing observation token for a process.
  func register(_ process: Process) -> ProcessObservationToken {
    if let existing = tokens[process.psn.lowLongOfPSN] {
      return existing
    }

    let token = ProcessObservationToken(
      keyPath: kind.keyPath,
      context: Unmanaged.passUnretained(process).toOpaque(),
      processID: process.psn.lowLongOfPSN
    )

    tokens[token.processID] = token

    return token
  }

  /// Remove and return an observation token for a process.
  func unregister(_ process: Process) -> ProcessObservationToken? {
    tokens.removeValue(forKey: process.psn.lowLongOfPSN)
  }
}
