import AppKit

struct StderrOutputStream: TextOutputStream {
    func write(_ string: String) { fputs(string, stderr) }
}

func printError(_ string: String) {
    var err = StderrOutputStream()
    print(string, to: &err)
}

let arguments = Arguments.parseOrExit()

func main(args _: [String]) -> Int32 {
    if arguments.version {
        return printVersion()
    }

    signal(SIGINT, handleSigInt)

    CFRunLoopRun()

    return EXIT_SUCCESS
}

exit(main(args: CommandLine.arguments))
