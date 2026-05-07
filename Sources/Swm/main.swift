import AppKit
import ArgumentParser
import SwmLib

func fail(_ message: String) -> Never {
  fputs("error: \(message)\n", stderr)
  exit(EXIT_FAILURE)
}

func runOrFail(_ message: String, _ operation: () throws -> Void) {
  do {
    try operation()
  } catch {
    fail("\(message) - \(error)")
  }
}

let arguments = Swm.parseOrExit()
setMinimumLogLevel(arguments.logLevel)

if arguments.help {
  fputs(Swm.helpMessage(), stderr)
  exit(EXIT_SUCCESS)
}

if arguments.version {
  print("swm version \(Version.current.value)")
  exit(EXIT_SUCCESS)
}

if let message = arguments.message {
  Client.send(message: message, args: arguments.args)
}

if getuid() == 0 || geteuid() == 0 {
  fail("running as root is not allowed")
}

if !Accessibility.askForAccessibilityIfNeeded() {
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

NSApplication.shared.run()
