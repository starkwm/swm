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
