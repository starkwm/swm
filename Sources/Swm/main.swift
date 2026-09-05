import AppKit
import SwmLib

if CommandLine.arguments.dropFirst() == ["--version"] {
  print("swm version \(Version.current.value)")
} else {
  Arguments.main()
}

/// Execute one parsed client or daemon invocation.
@MainActor
func runSwm(with arguments: StartCommand) {
  setMinimumLogLevel(arguments.logLevel)

  if getuid() == 0 || geteuid() == 0 {
    fail("running as root is not allowed")
  }

  if !AccessibilityClient.shared.askForAccessibilityIfNeeded() {
    fail("could not access accessibility features")
  }

  runOrFail("unable to create lock file") {
    try LockFile.acquire()
  }

  // Establish AppKit's window-system connection before runtime initialization
  // reads NSScreen, so screen changes are observed after docking and waking.
  let application = NSApplication.shared

  let workspace = Workspace()
  let processes = Processes()
  let windows = Windows(workspace: workspace)
  let spaces = Spaces()
  let displays = Displays()
  let tiling = Tiling(windows: windows, spaces: spaces)

  Events.shared.configure(
    workspace: workspace,
    processes: processes,
    windows: windows,
    spaces: spaces,
    displays: displays,
    tiling: tiling
  )

  if case .failure(let error) = displays.observe() {
    fail("unable to start display observation - \(error)")
  }

  if case .failure(let error) = processes.observe() {
    fail("unable to start process observation - \(error)")
  }

  windows.discover(from: processes.all())
  tiling.initialize()

  let daemon = Daemon(
    windows: windows,
    spaces: spaces,
    tiling: tiling
  )

  runOrFail("unable to run messaging daemon") {
    try daemon.run()
  }

  let terminationSignalSources = [SIGINT, SIGTERM].map { signalNumber in
    signal(signalNumber, SIG_IGN)

    let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
    source.setEventHandler {
      let signalName = signalNumber == SIGINT ? "SIGINT" : "SIGTERM"
      fputs("received \(signalName) - terminating...\n", stderr)
      daemon.shutdown()
      exit(EXIT_SUCCESS)
    }
    source.resume()
    return source
  }

  // Wait until the AppKit event loop is processing main-actor work before running
  // configuration commands, which call back into this daemon over IPC.
  DispatchQueue.main.async {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        if let configPath = arguments.config {
          try Config.exec(path: configPath)
        } else {
          try Config.execIfPresent(path: StartCommand.defaultConfigPath)
        }
      } catch {
        DispatchQueue.main.async {
          daemon.shutdown()
          fail("could not execute the configuration file - \(error)")
        }
      }
    }
  }

  // Run the AppKit event loop used by accessibility and workspace callbacks.
  withExtendedLifetime(terminationSignalSources) {
    application.run()
  }
}

/// Print an error message and terminate with failure.
func fail(_ message: String) -> Never {
  fputs("error: \(message)\n", stderr)
  exit(EXIT_FAILURE)
}

/// Run a throwing operation and terminate with a prefixed error on failure.
func runOrFail(_ message: String, _ operation: () throws -> Void) {
  do {
    try operation()
  } catch {
    fail("\(message) - \(error)")
  }
}
