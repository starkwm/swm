import CoreGraphics
import Testing

@testable import SwmLib

@Suite("CardinalDirection")
struct CardinalDirectionTests {
  @Test("rawValue: uses full CLI direction names")
  func rawValueUsesFullDirectionNames() {
    #expect(CardinalDirection(rawValue: "left") == .left)
    #expect(CardinalDirection(rawValue: "right") == .right)
    #expect(CardinalDirection(rawValue: "up") == .up)
    #expect(CardinalDirection(rawValue: "down") == .down)
    #expect(CardinalDirection(rawValue: "l") == nil)
  }

  @Test("neighbor: selects the window in each cardinal direction")
  func neighborSelectsCardinalWindows() {
    let frames: [CGWindowID: CGRect] = [
      1: CGRect(x: 100, y: 100, width: 100, height: 100),
      2: CGRect(x: 0, y: 100, width: 100, height: 100),
      3: CGRect(x: 200, y: 100, width: 100, height: 100),
      4: CGRect(x: 100, y: 0, width: 100, height: 100),
      5: CGRect(x: 100, y: 200, width: 100, height: 100),
    ]

    #expect(CardinalDirection.left.neighbor(of: 1, in: frames) == 2)
    #expect(CardinalDirection.right.neighbor(of: 1, in: frames) == 3)
    #expect(CardinalDirection.up.neighbor(of: 1, in: frames) == 4)
    #expect(CardinalDirection.down.neighbor(of: 1, in: frames) == 5)
  }

  @Test("neighbor: prefers an aligned window over a closer diagonal")
  func neighborPrefersAlignedWindow() {
    let frames: [CGWindowID: CGRect] = [
      1: CGRect(x: 100, y: 100, width: 100, height: 100),
      2: CGRect(x: 0, y: 125, width: 100, height: 50),
      3: CGRect(x: 75, y: 250, width: 50, height: 50),
    ]

    #expect(CardinalDirection.left.neighbor(of: 1, in: frames) == 2)
    #expect(CardinalDirection.up.neighbor(of: 1, in: frames) == nil)
    #expect(CardinalDirection.right.neighbor(of: 99, in: frames) == nil)
  }
}
