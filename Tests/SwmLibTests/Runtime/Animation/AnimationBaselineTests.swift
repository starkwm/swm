import Foundation
import Testing

@testable import SwmLib

@MainActor
@Suite("Animation baseline", .serialized)
struct AnimationBaselineTests {
  @Test(
    "controlled blocking delivery",
    .enabled(if: ProcessInfo.processInfo.environment["SWM_ANIMATION_BENCHMARK"] == "1")
  )
  func blockingDelivery() {
    var frames = Dictionary(
      uniqueKeysWithValues: (1...6).map {
        (UInt32($0), CGRect(x: 0, y: 0, width: 100, height: 100))
      }
    )
    let reconciler = WindowFrameReconciler(
      currentFrame: { id in
        Thread.sleep(forTimeInterval: 0.001)
        return frames[id]
      },
      frameMutation: { id, target, _ in
        Thread.sleep(forTimeInterval: 0.002)
        frames[id] = target
        return .success
      },
      automaticallySchedule: false,
      reduceMotion: { false }
    )
    reconciler.animationDuration = 1
    let start = ContinuousClock.now
    reconciler.apply(frames.mapValues { $0.offsetBy(dx: 100, dy: 0) }, at: start)
    var durations = [Double]()
    for step in 1...10 {
      let tick = ContinuousClock.now
      reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(step * 50)))
      durations.append(tick.duration(to: .now) / .milliseconds(1))
    }
    reconciler.cancelAnimations()
    print(
      "BLOCKING BASELINE six windows read=1ms write=2ms ticks=10 mean_ms=\(durations.reduce(0, +) / 10) max_ms=\(durations.max() ?? 0)"
    )
  }
  @Test(
    "controlled asynchronous delivery",
    .enabled(if: ProcessInfo.processInfo.environment["SWM_ANIMATION_BENCHMARK"] == "1")
  )
  func asynchronousDelivery() async throws {
    let app = AnimationTestApp(processID: 1, readDelay: 0.001, writeDelay: 0.002)
    let reconciler = WindowFrameReconciler(
      currentFrame: { app.frame(for: $0) },
      frameMutation: { _, _, _ in nil },
      delivery: AnimationFrameDelivery { app.backend(for: $0) },
      automaticallySchedule: false,
      reduceMotion: { false }
    )
    reconciler.animationDuration = 1
    let start = ContinuousClock.now.advanced(by: .seconds(10))
    let ids = (1...6).map { UInt32($0) }
    let target = CGRect(x: 100, y: 0, width: 100, height: 100)
    reconciler.apply(Dictionary(uniqueKeysWithValues: ids.map { ($0, target) }), at: start)
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !ids.allSatisfy({ reconciler.isAnimating($0) }), ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(1))
    }
    try #require(ids.allSatisfy { reconciler.isAnimating($0) })
    var durations = [Double]()
    for step in 1...10 {
      let tick = ContinuousClock.now
      reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(step * 50)))
      durations.append(tick.duration(to: .now) / .milliseconds(1))
      try await Task.sleep(for: .milliseconds(17))
    }
    reconciler.advanceAnimations(at: start.advanced(by: .seconds(1)))
    while !reconciler.isIdle, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(1))
    }
    #expect(reconciler.isIdle)
    #expect(ids.allSatisfy { app.frame(for: $0) == target })
    print(
      "ASYNC six windows one app read=1ms write=2ms ticks=10 mean_ms=\(durations.reduce(0, +) / 10) max_ms=\(durations.max() ?? 0) reads=\(app.readCount) writes=\(app.writeCount)"
    )
  }

}
