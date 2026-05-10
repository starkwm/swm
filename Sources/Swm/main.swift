import AppKit
import ArgumentParser
import SwmLib

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

/// Parsed command-line arguments for this invocation.
let arguments = Arguments.parseOrExit()
setMinimumLogLevel(arguments.logLevel)

if arguments.help {
  fputs(Arguments.helpMessage(), stderr)
  exit(EXIT_SUCCESS)
}

if arguments.version {
  print("swm version \(Version.current.value)")
  exit(EXIT_SUCCESS)
}

if let message = arguments.message {
  let result = Client.send(message: message, args: arguments.args)

  if let outputMessage = result.outputMessage {
    let stream = result.ok ? stdout : stderr
    fputs("\(outputMessage)\n", stream)
  }

  exit(result.ok ? EXIT_SUCCESS : EXIT_FAILURE)
}

// Daemon mode starts here.
if getuid() == 0 || geteuid() == 0 {
  fail("running as root is not allowed")
}

if !AccessibilityClient.shared.askForAccessibilityIfNeeded() {
  fail("could not access accessibility features")
}

runOrFail("unable to create lock file") {
  try LockFile.acquire()
}

let workspace = Workspace()
let processManager = ProcessManager()
let windowManager = WindowManager(workspace: workspace)
let spaceManager = SpaceManager()
let displayManager = DisplayManager()

EventManager.shared.configure(
  workspace: workspace,
  processManager: processManager,
  windowManager: windowManager,
  spaceManager: spaceManager,
  displayManager: displayManager
)

if case .failure(let error) = processManager.start() {
  fail("unable to start process manager - \(error)")
}

windowManager.start(processes: processManager.all())

let daemon = Daemon(
  windowManager: windowManager,
  spaceManager: spaceManager,
  displayManager: displayManager
)

runOrFail("unable to run messaging daemon") {
  try daemon.run()
}

runOrFail("could not execute the configuration file") {
  try Config.exec(path: arguments.config)
}

signal(SIGINT) { _ in
  fputs("received SIGINT - terminating...\n", stderr)
  daemon.shutdown()
  exit(EXIT_SUCCESS)
}

// Run the AppKit event loop used by accessibility and workspace callbacks.
NSApplication.shared.run()
