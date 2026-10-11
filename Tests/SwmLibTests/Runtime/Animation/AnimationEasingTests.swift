import Testing

@testable import SwmLib

@Suite("AnimationEasing")
struct AnimationEasingTests {
  @Test(
    "value: bounds monotonic curves with exact endpoints",
    arguments: AnimationEasing.allCases
  )
  func valueBoundsMonotonicCurvesWithExactEndpoints(easing: AnimationEasing) {
    #expect(easing.value(at: -1) == 0)
    #expect(easing.value(at: 0) == 0)
    #expect(easing.value(at: 1) == 1)
    #expect(easing.value(at: 2) == 1)
    var previous = 0.0
    for step in 0...100 {
      let value = easing.value(at: Double(step) / 100)
      #expect((0...1).contains(value))
      #expect(value >= previous)
      previous = value
    }
  }

  @Test("value: calculates each curve midpoint")
  func valueCalculatesEachCurveMidpoint() {
    #expect(AnimationEasing.linear.value(at: 0.5) == 0.5)
    #expect(AnimationEasing.easeOutQuad.value(at: 0.5) == 0.75)
    #expect(AnimationEasing.easeOutCubic.value(at: 0.5) == 0.875)
    #expect(abs(AnimationEasing.easeOutCirc.value(at: 0.5) - 0.866025403784) < 0.000001)
    #expect(AnimationEasing.easeInOutQuad.value(at: 0.5) == 0.5)
  }
}
