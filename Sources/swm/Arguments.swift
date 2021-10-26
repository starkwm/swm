import ArgumentParser
import Foundation

let defaultConfigPath = ("~/.config/swm/swmrc" as NSString).resolvingSymlinksInPath

struct Arguments: ParsableArguments {
    // --version/-v flag
    @Flag(name: .shortAndLong, help: "Show version information.")
    var version = false

    // --config/-c
    @Option(name: .shortAndLong, help: ArgumentHelp("Path to the configuration file.", valueName: "path"))
    var config: String = defaultConfigPath

    // --message/-m
    @Flag(name: .shortAndLong, help: "")
    var message = false
}
