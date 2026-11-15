import AppKit
import SwmLib

do {
  Arguments.main(try Arguments.resolve(Array(CommandLine.arguments.dropFirst())))
} catch {
  fputs("\(error)\n", stderr)
  exit(EX_USAGE)
}

@MainActor
func runSwm(with arguments: StartCommand) {
  setMinimumLogLevel(arguments.logLevel)

  if getuid() == 0 || geteuid() == 0 {
    fail("running as root is not allowed")
  }

  if !AccessibilityClient.shared.askForAccessibilityIfNeeded() {
    fail("could not access accessibility features")
  }

  AccessibilityClient.shared.limitMessagingTimeout()

  runOrFail("unable to create lock file") {
    try LockFile.acquire()
  }

  let application = NSApplication.shared

  let workspace = Workspace()
  let processes = Processes()
  let windows = Windows(workspace: workspace)
  let spaces: Spaces
  do {
    spaces = try Spaces()
  } catch {
    fail("unable to initialize Space queries - \(error)")
  }
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

  workspace.observe()

  if case .failure(let error) = displays.observe() {
    fail("unable to start display observation - \(error)")
  }

  if case .failure(let error) = processes.observe() {
    fail("unable to start process observation - \(error)")
  }

  windows.discover(from: processes) { tiling.initialize() }
  tiling.initialize()

  let daemon = Daemon(
    windows: windows,
    spaces: spaces,
    displays: displays,
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

  withExtendedLifetime(terminationSignalSources) {
    application.run()
  }
}

func fail(_ message: String) -> Never {
  fputs("Error: \(message)\n", stderr)
  exit(EXIT_FAILURE)
}

func runOrFail(_ message: String, _ operation: () throws -> Void) {
  do {
    try operation()
  } catch {
    fail("\(message) - \(error)")
  }
}
