import AppKit
import ArgumentParser

let majorVersion = 0
let minorVersion = 0
let patchVersion = 1

struct StderrOutputStream: TextOutputStream {
    func write(_ string: String) { fputs(string, stderr) }
}

func printError(_ string: String) {
    var err = StderrOutputStream()
    print(string, to: &err)
}

// swiftlint:disable let_var_whitespace
// XXX: re-enable once property wrappers do not trigger this

struct Arguments: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Display version information")
    var version: Bool = false
}

// swiftlint:enable let_var_whitespace

let arguments = Arguments.parseOrExit()

func printVersion() -> Int32 {
    print("swm version \(majorVersion).\(minorVersion).\(patchVersion)")
    return EXIT_SUCCESS
}

func main(args _: [String]) -> Int32 {
    if arguments.version {
        return printVersion()
    }

    return EXIT_SUCCESS
}

exit(main(args: CommandLine.arguments))
