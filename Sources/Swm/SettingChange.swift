import ArgumentParser
import Foundation

/// A setting value where a plain number sets it and a signed number adjusts it.
///
/// `6` sets the value, `+2` and `-2` adjust it, and the daemon's `abs:6` and `rel:2`
/// forms are also accepted.
struct SettingChange<Value: LosslessStringConvertible & Comparable & SignedNumeric>: Equatable,
  ExpressibleByArgument
{
  /// Whether the value adjusts the current setting instead of replacing it.
  let isRelative: Bool

  /// The value to set, or the signed amount to adjust by.
  let value: Value

  /// The daemon's `abs:<value>` or `rel:<value>` form.
  var ipcValue: String { "\(isRelative ? "rel" : "abs"):\(value)" }

  /// Parse a plain, signed, or `abs:`/`rel:` value.
  init?(argument: String) {
    let number: String
    if argument.hasPrefix("abs:") {
      (isRelative, number) = (false, String(argument.dropFirst(4)))
    } else if argument.hasPrefix("rel:") {
      (isRelative, number) = (true, String(argument.dropFirst(4)))
    } else {
      (isRelative, number) = (argument.hasPrefix("+") || argument.hasPrefix("-"), argument)
    }

    guard let value = Value(number) else { return nil }
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
/// The argument parser reads `-2` as an option, so `Arguments.resolve` rewrites a
/// negative number for these commands to the equivalent `rel:-2`.
protocol SettingChangeCommand: ParsableCommand {}

extension SettingChangeCommand {
  /// Rewrite negative numbers so the parser reads them as values.
  static func escapingNegativeNumbers(_ arguments: [String]) -> [String] {
    arguments.map { argument in
      isNegativeNumber(argument) ? "rel:\(argument)" : argument
    }
  }

  private static func isNegativeNumber(_ argument: String) -> Bool {
    argument.hasPrefix("-") && Double(argument) != nil
  }
}
