import AppKit
import ArgumentParser

let majorVersion = 0
let minorVersion = 0
let patchVersion = 1

let defaultConfigPath = ("~/.config/swm/swmrc" as NSString).resolvingSymlinksInPath

struct StderrOutputStream: TextOutputStream {
    func write(_ string: String) { fputs(string, stderr) }
}

func printError(_ string: String) {
    var err = StderrOutputStream()
    print(string, to: &err)
}

struct Arguments: ParsableArguments {
    // --version/-v flag
    @Flag(name: .shortAndLong, help: "")
    var version: Bool = false

    // --config/-c
    @Option(name: .shortAndLong, help: ArgumentHelp("", valueName: "path"))
    var config: String = defaultConfigPath

    // --message/-m
    @Flag(name: .shortAndLong, help: "")
    var message: Bool = false
}

let arguments = Arguments.parseOrExit()

func printVersion() -> Int32 {
    print("swm version \(majorVersion).\(minorVersion).\(patchVersion)")
    return EXIT_SUCCESS
}

func main(args _: [String]) -> Int32 {
    if arguments.version {
        return printVersion()
    }

    signal(SIGINT) { _ in
        print("received sigint - terminating...")
        NSApplication.shared.stop(nil)
    }

    NSApplication.shared.run()

    return EXIT_SUCCESS
}

exit(main(args: CommandLine.arguments))
