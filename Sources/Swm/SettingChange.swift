import ArgumentParser
import Foundation

struct SettingChange<Value: LosslessStringConvertible & Comparable & SignedNumeric>: Equatable,
  ExpressibleByArgument
{
  let isRelative: Bool

  let value: Value

  var ipcValue: String { "\(isRelative ? "rel" : "abs"):\(value)" }

  init?(argument: String) {
    guard let value = Value(argument) else { return nil }
    self.isRelative = argument.hasPrefix("+") || argument.hasPrefix("-")
    self.value = value
  }

  func validate(_ range: ClosedRange<Value>, name: String) throws {
    guard isRelative || range.contains(value) else {
      throw ValidationError("\(name) must be between \(range.lowerBound) and \(range.upperBound).")
    }
  }
}
