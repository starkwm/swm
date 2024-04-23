import AppKit
import ArgumentParser
import swmlib

let version = "0.0.1"

let arguments = Swm.parseOrExit()

if arguments.help {
  fputs(Swm.helpMessage(), stderr)
  exit(EXIT_SUCCESS)
}

if arguments.version {
  print("swm version \(version)")
  exit(EXIT_SUCCESS)
}

if let message = arguments.message {
  Client.send(message: message.rawValue, args: arguments.args)
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
