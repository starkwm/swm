import AppKit
import ArgumentParser
import SwmLib

let arguments = Swm.parseOrExit()

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
  fputs("error: running as root is not allowed\n", stderr)
  exit(EXIT_FAILURE)
}

if !Accessibility.askForAccessibilityIfNeeded() {
  fputs("error: could not access accessbility features\n", stderr)
  exit(EXIT_FAILURE)
}

do {
  try LockFile.acquire()
} catch {
  fputs("error: unable to create lock file - \(error)\n", stderr)
  exit(EXIT_FAILURE)
}

let processManager = ProcessManager()
EventManager.shared.configure(processLookup: processManager)

switch processManager.start() {
case .success:
  break
case .failure(let error):
  fputs("error: unable to start process manager - \(error)\n", stderr)
  exit(EXIT_FAILURE)
}

WindowManager.shared.start(processes: processManager.all())

let daemon = Daemon()

do {
  try daemon.run()
} catch {
  fputs("error: unable to run messaging daemon - \(error)\n", stderr)
  exit(EXIT_FAILURE)
}

do {
  try Config.exec(path: arguments.config)
} catch {
  fputs("error: could not execute the configuration file - \(error)\n", stderr)
  exit(EXIT_FAILURE)
}

signal(SIGINT) { _ in
  fputs("received SIGINT - terminating...\n", stderr)
  daemon.shutdown()
  exit(EXIT_SUCCESS)
}

NSApplication.shared.run()
