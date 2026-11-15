import Foundation

@MainActor
final class ConfigReload {
  typealias ProcessWatcher = (pid_t, @escaping @MainActor @Sendable () -> Void) -> (() -> Void)?

  private struct Transaction {
    let token: String
    let staging: ReloadStaging
    let settings: ReloadSettings
    let stopWatching: () -> Void
  }

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
    guard kill(processID, 0) == 0 || errno == EPERM else {
      source.cancel()
      return nil
    }
    return { source.cancel() }
  }

  private let tiling: Tiling
  private let spaces: Spaces
  private let windows: Windows
  private let signals: Signals
  private let watchProcess: ProcessWatcher
  private let makeToken: () -> String
  private var transaction: Transaction?

  init(
    tiling: Tiling,
    spaces: Spaces,
    windows: Windows,
    signals: Signals = .shared,
    watchProcess: @escaping ProcessWatcher = { watchExit(of: $0, onExit: $1) },
    makeToken: @escaping () -> String = { UUID().uuidString }
  ) {
    self.tiling = tiling
    self.spaces = spaces
    self.windows = windows
    self.signals = signals
    self.watchProcess = watchProcess
    self.makeToken = makeToken
  }

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

    transaction = Transaction(
      token: token,
      staging: ReloadStaging(),
      settings: ReloadSettings(
        spaces: spaces.settingsSnapshot(),
        tiling: tiling.settingsSnapshot(),
        focusFollowsMouse: windows.focusFollowsMouseMode
      ),
      stopWatching: stopWatching
    )
    log("configuration reload started", level: .info)
    return token
  }

  func commit(token: String) throws {
    let transaction = try close(token: token)
    signals.replaceAll(transaction.staging.signals)
    tiling.replaceRules(transaction.staging.rules)
    log("configuration reload committed", level: .info)
  }

  func rollback(token: String) throws {
    let settings = try close(token: token).settings
    if windows.focusFollowsMouseMode != settings.focusFollowsMouse {
      windows.setFocusFollowsMouseMode(settings.focusFollowsMouse)
    }
    let spacesChanged = spaces.settingsSnapshot() != settings.spaces
    spaces.restoreSettings(settings.spaces)
    if tiling.restoreSettings(settings.tiling) || spacesChanged {
      tiling.reconcileAndReflowVisibleSpaces()
    }
    log("configuration reload rolled back", level: .info)
  }

  func staging(for request: IPCRequest) -> ReloadStaging? {
    guard let token = request.transaction else { return nil }
    guard let transaction, transaction.token == token else {
      log("applying \(request.domain.rawValue) \(request.command) live; its reload is not open")
      return nil
    }
    return transaction.staging
  }

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

private struct ReloadSettings {
  let spaces: SpaceSettingsSnapshot
  let tiling: TilingSettingsSnapshot
  let focusFollowsMouse: FocusFollowsMouseMode
}

@MainActor
final class ReloadStaging {
  private(set) var rules = [WindowRule]()

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
