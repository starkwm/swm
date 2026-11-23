import ArgumentParser
import CoreGraphics
import Foundation
import SwmLib

struct SettingChange<Value: LosslessStringConvertible & Comparable & SignedNumeric>: Equatable,
  ExpressibleByArgument
{
  let isRelative: Bool

  let value: Value

  var numericChange: NumericChange<Value> {
    isRelative ? .relative(value) : .absolute(value)
  }

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

extension SettingChange<Double> {
  var ratioChange: LayoutRatioChange {
    isRelative ? .relative(CGFloat(value)) : .absolute(CGFloat(value))
  }
}
