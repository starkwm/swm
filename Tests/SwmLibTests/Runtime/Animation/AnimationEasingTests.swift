import Testing

@testable import SwmLib

@Suite("AnimationEasing")
struct AnimationEasingTests {
  @Test(
    "value: preserves curve midpoints, monotonic bounds, and exact endpoints",
    arguments: AnimationEasing.allCases
  )
  func valuePreservesCurveMidpointsMonotonicBoundsAndExactEndpoints(easing: AnimationEasing) {
    let midpoint: Double
    switch easing {
    case .linear, .easeInOutQuad: midpoint = 0.5
    case .easeOutQuad: midpoint = 0.75
    case .easeOutCubic: midpoint = 0.875
    case .easeOutCirc: midpoint = 0.866025403784
    }
    #expect(easing.value(at: -1) == 0)
    #expect(easing.value(at: 2) == 1)
    var previous = 0.0
    for step in 0...100 {
      let value = easing.value(at: Double(step) / 100)
      #expect((0...1).contains(value))
      #expect(value >= previous)
      if step == 0 { #expect(value == 0) }
      if step == 50 { #expect(abs(value - midpoint) < 0.000001) }
      if step == 100 { #expect(value == 1) }
      previous = value
    }
  }
}
