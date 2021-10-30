import AppKit
import swmlib

func main(args _: [String]) -> Int32 {
    if arguments.version {
        return printVersion()
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
