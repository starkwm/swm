import ArgumentParser

/// A command whose positional values may be negative numbers such as `-20` or `-0.05`.
protocol SignedPositionalCommand: ParsableCommand {
  /// Options that consume the following argument, so it is not escaped as a positional.
  static var valueOptions: Set<String> { get }
}

extension SignedPositionalCommand {
  /// Move options before `--` and values after it, keeping value order.
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
      } else if argument.hasPrefix("-"), Double(argument) == nil {
        options.append(argument)
        expectsValue = valueOptions.contains(argument)
      } else {
        values.append(argument)
      }
    }
    return options + ["--"] + values
  }
}
