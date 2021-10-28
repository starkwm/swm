import ArgumentParser
import Foundation

let defaultConfigPath = ("~/.config/swm/swmrc" as NSString).resolvingSymlinksInPath

struct Arguments: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Show version information.")
    var version = false

    @Option(name: .shortAndLong, help: ArgumentHelp("Path to the configuration file.", valueName: "path"))
    var config: String = defaultConfigPath

    @Flag(name: .shortAndLong, help: "")
    var message = false
}
