import CoreGraphics

public enum QuerySelection: Codable, Equatable, Sendable {
  case none

  case display(Int?)

  case space(Int?)

  case window(CGWindowID?)
}
