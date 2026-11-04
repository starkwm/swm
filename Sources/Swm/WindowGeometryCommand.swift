/// A window command accepting numeric positionals and options.
protocol WindowGeometryCommand: WindowIPCCommand {
  /// Options that consume the following argument, so it is not escaped as a positional.
  static var valueOptions: Set<String> { get }
}

extension WindowGeometryCommand {
  /// Keep options before `--` and both coordinates after it, preserving axis order.
  /// ArgumentParser otherwise treats negative positional numbers as options.
  static func escapingPositionals(_ arguments: [String]) -> [String] {
    var options = [String]()
    var values = [String]()
    var expectsValue = false
    var afterTerminator = false
    for argument in arguments {
      if afterTerminator {
        values.append(argument)
      } else if expectsValue {
        options.append(argument)
        expectsValue = false
      } else if argument == "--" {
        afterTerminator = true
      } else if argument.hasPrefix("-"), Int(argument) == nil {
        options.append(argument)
        expectsValue = valueOptions.contains(argument)
      } else {
        values.append(argument)
      }
    }
    return options + ["--"] + values
  }
}
