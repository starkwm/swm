import AppKit
import Testing

@testable import SwmLib

func animationFrame(_ x: Double) -> CGRect { CGRect(x: x, y: 0, width: 100, height: 100) }

@MainActor
func makeTestReconciler(
  _ app: AnimationTestApp,
  delivery: AnimationFrameDelivery? = nil,
  automaticallySchedule: Bool = false,
  reduceMotion: @escaping () -> Bool = { false },
  terminalFailure: @escaping (CGWindowID) -> Void = { _ in }
) -> WindowFrameReconciler {
  WindowFrameReconciler(
    currentFrame: { app.frame(for: $0) },
    delivery: delivery ?? AnimationFrameDelivery { app.backend(for: $0) },
    automaticallySchedule: automaticallySchedule,
    terminalFailure: terminalFailure,
    reduceMotion: reduceMotion
  )
}

@MainActor
func waitForAnimation(_ condition: () -> Bool) async throws {
  let deadline = ContinuousClock.now.advanced(by: .seconds(3))
  while !condition(), ContinuousClock.now < deadline {
    try await Task.sleep(for: .milliseconds(1))
  }
  try #require(condition())
}
