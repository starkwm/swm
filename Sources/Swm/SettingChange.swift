import ArgumentParser
import Foundation

/// A setting value where a plain number sets it and a signed number adjusts it.
///
/// `6` sets the value, and `+2` and `-2` adjust it.
struct SettingChange<Value: LosslessStringConvertible & Comparable & SignedNumeric>: Equatable,
  ExpressibleByArgument
{
  /// Whether the value adjusts the current setting instead of replacing it.
  let isRelative: Bool

  /// The value to set, or the signed amount to adjust by.
  let value: Value

  /// The daemon's `abs:<value>` or `rel:<value>` form.
  var ipcValue: String { "\(isRelative ? "rel" : "abs"):\(value)" }

  /// Parse a plain or signed value.
  init?(argument: String) {
    guard let value = Value(argument) else { return nil }
    self.isRelative = argument.hasPrefix("+") || argument.hasPrefix("-")
    self.value = value
  }

  /// Reject absolute values outside a range; adjustments are clamped by the daemon.
  func validate(_ range: ClosedRange<Value>, name: String) throws {
    guard isRelative || range.contains(value) else {
      throw ValidationError("\(name) must be between \(range.lowerBound) and \(range.upperBound).")
    }
  }
}

/// A command whose positional value may be a negative adjustment such as `-2`.
///
/// The argument parser reads `-2` as an option, so `Arguments.resolve` moves a
/// negative positional number after a `--` terminator for these commands.
protocol SettingChangeCommand: ParsableCommand {}

extension SettingChangeCommand {
  /// Move negative positional numbers after `--` so the parser reads them as values.
  ///
  /// A negative number that follows an option name is that option's value and stays put.
  static func escapingNegativeNumbers(_ arguments: [String]) -> [String] {
    guard !arguments.contains("--") else { return arguments }

    var kept = [String]()
    var values = [String]()
    for argument in arguments {
      if isNegativeNumber(argument), kept.last?.hasPrefix("--") != true {
        values.append(argument)
      } else {
        kept.append(argument)
      }
    }
    return values.isEmpty ? arguments : kept + ["--"] + values
  }

  private static func isNegativeNumber(_ argument: String) -> Bool {
    argument.hasPrefix("-") && Double(argument) != nil
  }
}
