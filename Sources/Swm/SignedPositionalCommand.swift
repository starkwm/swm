import ArgumentParser

protocol SignedPositionalCommand: ParsableCommand {
  static var valueOptions: Set<String> { get }
}

extension SignedPositionalCommand {
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
