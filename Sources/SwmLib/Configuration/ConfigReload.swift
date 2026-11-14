import Foundation

/// Stages rule and signal registrations from a configuration reload, then swaps them in at once.
///
/// Each command the configuration file runs arrives as its own request tagged with the reload's
/// token. Rule and signal commands change staged lists instead of the live ones, so the daemon
/// always runs with either the old or the new registrations, and a failed reload leaves them
/// untouched. A request with no token, or with a token that is not the open reload's, applies
/// live; programs the file leaves running inherit the token, so a closed token must not block
/// their commands.
@MainActor
final class ConfigReload {
  /// Watch a process and call `onExit` once when it exits.
  ///
  /// Returns an action that stops watching, or nil when the process is not running.
  typealias ProcessWatcher = (pid_t, @escaping @MainActor @Sendable () -> Void) -> (() -> Void)?

  private struct Transaction {
    let token: String
    let staging: ReloadStaging
    let stopWatching: () -> Void
  }

  /// Watch a process exit on the main queue.
  ///
  /// Keep the returned action until the watch ends, because the source does not outlive it.
  ///
  /// The returned action owns the watch: releasing it without calling it stops watching.
  static func watchExit(
    of processID: pid_t,
    onExit: @escaping @MainActor @Sendable () -> Void
  ) -> (() -> Void)? {
    let source = DispatchSource.makeProcessSource(
      identifier: processID,
      eventMask: .exit,
      queue: .main
    )
    source.setEventHandler { [weak source] in
      source?.cancel()
      MainActor.assumeIsolated { onExit() }
    }
    source.resume()
    // A process that exited before the source was armed delivers no event.
    guard kill(processID, 0) == 0 || errno == EPERM else {
      source.cancel()
      return nil
    }
    return { source.cancel() }
  }

  private let tiling: Tiling
  private let signals: Signals
  private let watchProcess: ProcessWatcher
  private let makeToken: () -> String
  private var transaction: Transaction?

  init(
    tiling: Tiling,
    signals: Signals = .shared,
    watchProcess: @escaping ProcessWatcher = { watchExit(of: $0, onExit: $1) },
    makeToken: @escaping () -> String = { UUID().uuidString }
  ) {
    self.tiling = tiling
    self.signals = signals
    self.watchProcess = watchProcess
    self.makeToken = makeToken
  }

  /// Open a reload for the process that will run the configuration file.
  ///
  /// Only one reload can be open. It rolls back if the process exits before finishing it.
  func begin(processID: pid_t) throws -> String {
    guard transaction == nil else {
      throw IPCCommandError.invalidRequest("a configuration reload is already in progress")
    }

    let token = makeToken()
    guard
      let stopWatching = watchProcess(processID, { [weak self] in self?.abandon(token: token) })
    else {
      throw IPCCommandError.invalidRequest("reload process is not running: \(processID)")
    }

    transaction = Transaction(token: token, staging: ReloadStaging(), stopWatching: stopWatching)
    log("configuration reload started", level: .info)
    return token
  }

  /// Replace the live rules and signals with the staged ones.
  func commit(token: String) throws {
    let transaction = try close(token: token)
    signals.replaceAll(transaction.staging.signals)
    tiling.replaceRules(transaction.staging.rules)
    log("configuration reload committed", level: .info)
  }

  /// Discard the staged rules and signals.
  func rollback(token: String) throws {
    _ = try close(token: token)
    log("configuration reload rolled back", level: .info)
  }

  /// The staged registrations a request changes, or nil when it applies live.
  func staging(for request: IPCRequest) -> ReloadStaging? {
    guard let token = request.transaction else { return nil }
    guard let transaction, transaction.token == token else {
      log("applying \(request.domain.rawValue) \(request.command) live; its reload is not open")
      return nil
    }
    return transaction.staging
  }

  /// Roll back a reload whose process exited without finishing it.
  private func abandon(token: String) {
    guard transaction?.token == token else { return }
    log("configuration reload process exited before finishing", level: .warn)
    try? rollback(token: token)
  }

  private func close(token: String) throws -> Transaction {
    guard let transaction, transaction.token == token else {
      throw IPCCommandError.invalidRequest("no configuration reload is in progress for \(token)")
    }
    self.transaction = nil
    transaction.stopWatching()
    return transaction
  }
}

/// Rule and signal registrations built by an open configuration reload.
@MainActor
final class ReloadStaging {
  /// Staged rules in registration order.
  private(set) var rules = [WindowRule]()

  /// Staged signals in registration order.
  private(set) var signals = [Signal]()

  func addRule(_ rule: WindowRule) throws {
    try rules.appendUniquelyLabeled(rule, kind: "rule", label: \.label)
  }

  func removeRule(selector: String) throws {
    try rules.remove(selector: selector, kind: "rule", label: \.label)
  }

  func removeAllRules() {
    rules.removeAll()
  }

  func addSignal(_ signal: Signal) throws {
    try signals.appendUniquelyLabeled(signal, kind: "signal", label: \.label)
  }

  func removeSignal(selector: String) throws {
    try signals.remove(selector: selector, kind: "signal", label: \.label)
  }

  func removeAllSignals() {
    signals.removeAll()
  }
}
