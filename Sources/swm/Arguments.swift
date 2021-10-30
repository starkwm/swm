import ArgumentParser
import Foundation

struct Arguments: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Show version information.")
    var version = false

    @Option(name: .shortAndLong, help: ArgumentHelp("Path to the configuration file.", valueName: "path"))
    var config: String = ("~/.config/swm/swmrc" as NSString).resolvingSymlinksInPath

    @Flag(name: .shortAndLong, help: "")
    var message = false
}

let arguments = Arguments.parseOrExit()
