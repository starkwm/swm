/// A window command with two numeric positional values and an absolute flag.
protocol WindowGeometryCommand: WindowIPCCommand {}

extension WindowGeometryCommand {
  /// Keep options before `--` and both coordinates after it, preserving axis order.
  /// ArgumentParser otherwise treats negative positional numbers as options.
  static func escapingPositionals(_ arguments: [String]) -> [String] {
    var options = [String]()
    var values = [String]()
    var expectsWindow = false
    var afterTerminator = false
    for argument in arguments {
      if afterTerminator {
        values.append(argument)
      } else if expectsWindow {
        options.append(argument)
        expectsWindow = false
      } else if argument == "--" {
        afterTerminator = true
      } else if argument.hasPrefix("-"), Int(argument) == nil {
        options.append(argument)
        expectsWindow = argument == "--window"
      } else {
        values.append(argument)
      }
    }
    return options + ["--"] + values
  }
}
