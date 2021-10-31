import AppKit
import ArgumentParser
import swmlib

let version = "0.0.1"

struct Arguments: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Show version information.")
    var version = false

    @Option(name: .shortAndLong, help: ArgumentHelp("Path to the configuration file.", valueName: "path"))
    var config: String = ("~/.config/swm/swmrc" as NSString).resolvingSymlinksInPath

    @Flag(name: .shortAndLong, help: "")
    var message = false
}

let arguments = Arguments.parseOrExit()

func main() -> Int32 {
    if arguments.version {
        print("swm version \(version)")
        return EXIT_SUCCESS
    }

    do {
        try LockFile.acquire()
    } catch {
        printError("error creating pid file: \(error)")
        return EXIT_FAILURE
    }

    signal(SIGINT) { _ in
        print("received SIGINT - terminating...")
        CFRunLoopStop(CFRunLoopGetCurrent())
    }

    CFRunLoopRun()

    return EXIT_SUCCESS
}

exit(main())
