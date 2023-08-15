import AppKit
import ArgumentParser
import swmlib

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
