import AppKit
import swmlib

let version = "0.0.1"

func main(args _: [String]) -> Int32 {
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

    signal(SIGINT, handleSigInt)

    CFRunLoopRun()

    return EXIT_SUCCESS
}

exit(main(args: CommandLine.arguments))
