import Foundation
import Testing

@testable import SwmLib

@MainActor
@Suite("ConfigReload")
struct ConfigReloadTests {
  @Test("commit: swaps staged rules and signals in at once, leaving live ones until then")
  func commitSwapsStagedRulesAndSignalsInAtOnce() throws {
    let fixture = ReloadFixture()
    try fixture.tiling.addRule(WindowRule.parse(arguments: ["label=old", "manage=off"]))
    #expect(
      fixture.send(.signal, "--add", ["label=old", "event=window-focused", "action=true"]).ok
    )
    let token = try fixture.begin()

    #expect(fixture.send(.rule, "--clear", token: token).ok)
    #expect(fixture.send(.rule, "--add", ["label=new", "manage=off"], token: token).ok)
    #expect(fixture.send(.signal, "--clear", token: token).ok)
    #expect(
      fixture.send(
        .signal,
        "--add",
        ["label=new", "event=space-changed", "action=true"],
        token: token
      )
      .ok
    )
    // A duplicate is checked against the staged registrations, not the live ones.
    #expect(!fixture.send(.rule, "--add", ["label=new", "manage=on"], token: token).ok)
    #expect(
      fixture.send(
        .signal,
        "--add",
        ["label=old", "event=window-focused", "action=true"],
        token: token
      ).ok
    )

    #expect(fixture.tiling.rules.map(\.label) == ["old"])
    #expect(fixture.signals.list().map(\.signal.label) == ["old"])
    #expect(try fixture.labels(.rule, token: token) == ["new"])
    #expect(try fixture.labels(.signal, token: token) == ["new", "old"])
    #expect(try fixture.labels(.rule) == ["old"])

    #expect(fixture.send(.config, "--commit-reload", [token]).ok)
    #expect(fixture.tiling.rules.map(\.label) == ["new"])
    #expect(fixture.signals.list().map(\.signal.label) == ["new", "old"])
    #expect(fixture.stoppedWatching)
  }

  @Test("commit: an identical rule set does not place matching windows again")
  func commitAnIdenticalRuleSetDoesNotPlaceMatchingWindowsAgain() throws {
    var placements = 0
    let fixture = ReloadFixture(
      tiling: makeTiling(rulePlacement: { _, _, _ in
        placements += 1
        return .applied
      })
    )
    let rule = ["label=grid", "grid=2:1:1:0:1:1"]
    #expect(fixture.send(.rule, "--add", rule).ok)
    #expect(placements == 1)

    let token = try fixture.begin()
    #expect(fixture.send(.rule, "--clear", token: token).ok)
    #expect(fixture.send(.rule, "--add", rule, token: token).ok)
    #expect(fixture.send(.config, "--commit-reload", [token]).ok)
    #expect(placements == 1)

    // Clearing and adding the rule live, as reload used to, places the window again.
    #expect(fixture.send(.rule, "--clear").ok)
    #expect(fixture.send(.rule, "--add", rule).ok)
    #expect(placements == 2)
  }

  @Test("rollback: discards staged changes and accepts a new reload")
  func rollbackDiscardsStagedChangesAndAcceptsANewReload() throws {
    let fixture = ReloadFixture()
    try fixture.tiling.addRule(WindowRule.parse(arguments: ["label=old", "manage=off"]))
    let token = try fixture.begin()
    #expect(fixture.send(.rule, "--clear", token: token).ok)
    #expect(!fixture.send(.config, "--begin-reload", ["42"]).ok)
    #expect(!fixture.send(.config, "--commit-reload", ["other"]).ok)

    #expect(fixture.send(.config, "--rollback-reload", [token]).ok)
    #expect(fixture.tiling.rules.map(\.label) == ["old"])
    #expect(fixture.stoppedWatching)
    #expect(!fixture.send(.config, "--commit-reload", [token]).ok)
    _ = try fixture.begin()
  }

  @Test(
    "rollback: restores settings the reload changed, and commit keeps them",
    arguments: [false, true]
  )
  func rollbackRestoresSettingsTheReloadChangedAndCommitKeepsThem(commit: Bool) throws {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]]
    )
    tiling.initialize()
    let fixture = ReloadFixture(tiling: tiling)
    #expect(fixture.send(.config, "gap", ["abs:4"]).ok)
    let before = fixture.settings
    let token = try fixture.begin()

    for (setting, value) in [
      ("layout", ["dwindle"]), ("master-ratio", ["abs:0.6"]), ("master-placement", ["top"]),
      ("split-ratio", ["abs:0.7"]), ("preserve-split", ["on"]), ("gap", ["abs:12"]),
      ("padding", ["top=abs:8"]), ("focus-follows-mouse", ["autofocus"]),
    ] {
      #expect(fixture.send(.config, setting, value, token: token).ok)
    }
    fixture.spaces.setGap(30, for: 10)
    let plan = try #require(tiling.layoutPlan(for: layoutID(10)))

    #expect(fixture.send(.config, commit ? "--commit-reload" : "--rollback-reload", [token]).ok)
    if commit {
      #expect(fixture.settings != before)
      #expect(tiling.layoutPlan(for: layoutID(10)) == plan)
    } else {
      #expect(fixture.settings == before)
      #expect(tiling.layoutPlan(for: layoutID(10)) == nil)
    }
  }

  @Test("begin: rolls back when the reload process exits before finishing")
  func beginRollsBackWhenTheReloadProcessExitsBeforeFinishing() throws {
    let fixture = ReloadFixture()
    let token = try fixture.begin()
    #expect(fixture.send(.rule, "--add", ["label=new", "manage=off"], token: token).ok)

    fixture.exitProcess()
    #expect(fixture.tiling.rules.isEmpty)
    #expect(!fixture.send(.config, "--commit-reload", [token]).ok)
    _ = try fixture.begin()
  }

  @Test("begin: rejects a process that is not running and malformed process IDs")
  func beginRejectsAProcessThatIsNotRunningAndMalformedProcessIDs() {
    let fixture = ReloadFixture(runningProcessIDs: [])
    for value in ["42", "0", "-1", "x"] {
      #expect(!fixture.send(.config, "--begin-reload", [value]).ok)
    }
    #expect(!fixture.send(.config, "--begin-reload").ok)
  }

  @Test("staging: applies requests with an unknown or closed token live")
  func stagingAppliesRequestsWithAnUnknownOrClosedTokenLive() throws {
    let fixture = ReloadFixture()
    #expect(fixture.send(.rule, "--add", ["label=a", "manage=off"], token: "unknown").ok)
    let token = try fixture.begin()
    #expect(fixture.send(.rule, "--add", ["label=b", "manage=off"], token: "unknown").ok)
    #expect(fixture.send(.config, "--commit-reload", [token]).ok)
    // A program the configuration file left running still sends the old token.
    #expect(fixture.send(.rule, "--add", ["label=c", "manage=off"], token: token).ok)
    #expect(
      fixture.send(
        .signal,
        "--add",
        ["label=c", "event=window-focused", "action=true"],
        token: token
      ).ok
    )
    #expect(fixture.tiling.rules.map(\.label) == ["c"])
    #expect(fixture.signals.list().map(\.signal.label) == ["c"])
  }

  @Test("watchExit: reports a process exit and rejects a process that is not running")
  func watchExitReportsAProcessExitAndRejectsAProcessThatIsNotRunning() async throws {
    let input = Pipe()
    let process = Foundation.Process()
    process.executableURL = URL(fileURLWithPath: "/bin/cat")
    process.standardInput = input
    process.standardOutput = FileHandle.nullDevice
    try process.run()

    // The returned action owns the source, so it must stay alive until the exit arrives.
    var stop: (() -> Void)?
    let exited = await withCheckedContinuation { continuation in
      stop = ConfigReload.watchExit(of: process.processIdentifier) {
        continuation.resume(returning: true)
      }
      try? input.fileHandleForWriting.close()
    }
    #expect(stop != nil)
    #expect(exited)
    process.waitUntilExit()
    #expect(ConfigReload.watchExit(of: process.processIdentifier) {} == nil)
  }
}

/// A reload backed by a test tiling, a private signal registry, and a simulated process.
@MainActor
private final class ReloadFixture {
  let tiling: Tiling
  let spaces: Spaces
  let windows = Windows(workspace: Workspace(), focusedWindowID: nil)
  let signals = Signals()
  var stoppedWatching: Bool { process.stopped }

  /// Every setting a rollback restores.
  var settings: ReloadedSettings {
    ReloadedSettings(
      spaces: spaces.settingsSnapshot(),
      tiling: tiling.settingsSnapshot(),
      focusFollowsMouse: windows.focusFollowsMouseMode
    )
  }
  private let process = WatchedProcess()
  private let reload: ConfigReload

  init(
    tiling: Tiling = makeTiling(),
    spaces: Spaces = Spaces(activeSpaceID: nil),
    runningProcessIDs: Set<pid_t> = [42]
  ) {
    self.tiling = tiling
    self.spaces = spaces
    reload = ConfigReload(
      tiling: tiling,
      spaces: spaces,
      windows: windows,
      signals: signals,
      watchProcess: { [process] processID, onExit in
        guard runningProcessIDs.contains(processID) else { return nil }
        process.onExit = onExit
        process.stopped = false
        return { process.stopped = true }
      }
    )
  }

  func begin() throws -> String {
    let response = send(.config, "--begin-reload", ["42"])
    try #require(response.ok)
    return response.message
  }

  func exitProcess() {
    process.onExit?()
  }

  func send(
    _ domain: CommandDomain,
    _ command: String,
    _ args: [String] = [],
    token: String? = nil
  ) -> IPCResponse {
    let request = IPCRequest(domain: domain, command: command, args: args, transaction: token)
    return switch domain {
    case .rule: RuleCommandHandler(tiling: tiling, reload: reload).dispatch(request)
    case .signal: SignalCommandHandler(signals: signals, reload: reload).dispatch(request)
    case .config where !ConfigReloadCommandHandler.commands.contains(command):
      // Settings commands are not staged, so the request's token does not route them.
      ConfigCommandHandler(windows: windows, spaces: spaces, tiling: tiling).dispatch(request)
    default: ConfigReloadCommandHandler(reload: reload).dispatch(request)
    }
  }

  func labels(_ domain: CommandDomain, token: String? = nil) throws -> [String?] {
    let response = send(domain, "--list", token: token)
    let entries = try #require(
      JSONSerialization.jsonObject(with: Data(response.message.utf8)) as? [[String: Any]]
    )
    return entries.map {
      ($0["label"] as? String) ?? (($0["rule"] as? [String: String])?["label"])
    }
  }
}

/// Every setting a rollback restores, compared as one value.
private struct ReloadedSettings: Equatable {
  let spaces: SpaceSettingsSnapshot
  let tiling: TilingSettingsSnapshot
  let focusFollowsMouse: FocusFollowsMouseMode
}

/// The simulated reload process a fixture watches.
@MainActor
private final class WatchedProcess {
  var onExit: (@MainActor @Sendable () -> Void)?
  var stopped = false
}
