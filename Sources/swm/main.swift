import AppKit
import ArgumentParser
import swmlib

let version = "0.0.1"

extension MessageDomain: ExpressibleByArgument {}

struct Arguments: ParsableArguments {
    @Flag(name: .shortAndLong)
    var help = false

    @Flag(name: .shortAndLong, help: "Show version information.")
    var version = false

    @Option(name: .shortAndLong, help: ArgumentHelp("Path to the configuration file.", valueName: "path"))
    var config: String = ("~/.config/swm/swmrc" as NSString).resolvingSymlinksInPath

    @Option(name: .shortAndLong)
    var message: MessageDomain?

    @Argument(parsing: .unconditionalRemaining)
    var args: [String] = []
}

let arguments = Arguments.parseOrExit()

func main() -> Int32 {
    if arguments.help {
        fputs(Arguments.helpMessage(), stderr)
        return EXIT_SUCCESS
    }

    if arguments.version {
        print("swm version \(version)")
        return EXIT_SUCCESS
    }

    if let message = arguments.message {
        do {
            return try Client.send(message: message, args: arguments.args)
        } catch {
            fputs("error: could not send message - \(error)\n", stderr)
            return EXIT_FAILURE
        }
    }

    if getuid() == 0 || geteuid() == 0 {
        fputs("error: running as root is not allowed\n", stderr)
        return EXIT_FAILURE
    }

    do {
        try LockFile.acquire()
    } catch {
        fputs("error: unable to create lock file - \(error)\n", stderr)
        return EXIT_FAILURE
    }

    let daemon = Daemon()

    do {
        try daemon.run()
    } catch {
        fputs("error: unable to run messaging daemon - \(error)\n", stderr)
        return EXIT_FAILURE
    }

    signal(SIGINT) { _ in
        print("received SIGINT - terminating...")
        CFRunLoopStop(CFRunLoopGetCurrent())
    }

    CFRunLoopRun()

    daemon.shutdown()

    return EXIT_SUCCESS
}

exit(main())
