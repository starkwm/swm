import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("WindowFrameReconciler")
struct WindowFrameReconcilerTests {
  @Test("apply: skips matching frames within tolerance")
  func applySkipsMatchingFramesWithinTolerance() {
    var mutationCount = 0
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in CGRect(x: 0.5, y: 0, width: 100, height: 100) },
      frameMutation: { _, _, _ in
        mutationCount += 1
        return .success
      }
    )

    reconciler.apply([1: CGRect(x: 0, y: 0, width: 100, height: 100)])

    #expect(mutationCount == 0)
  }

  @Test("apply: registers the entire batch before the first mutation")
  func applyRegistersEntireBatchBeforeFirstMutation() throws {
    var reconciler: WindowFrameReconciler!
    reconciler = WindowFrameReconciler(
      currentFrame: { _ in .zero },
      frameMutation: { windowID, _, _ in
        #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: .zero))
        #expect(reconciler.shouldSuppressNotification(for: 2, actualFrame: .zero))
        #expect([CGWindowID(1), 2].contains(windowID))
        return .success
      }
    )

    reconciler.apply([
      1: CGRect(x: 0, y: 0, width: 100, height: 100),
      2: CGRect(x: 100, y: 0, width: 100, height: 100),
    ])
  }

  @Test("apply: reports failures and bounds their feedback suppression")
  func applyReportsFailuresAndBoundsTheirFeedbackSuppression() {
    let reconciler = WindowFrameReconciler(
      currentFrame: { windowID in windowID == 1 ? .zero : nil },
      frameMutation: { _, _, _ in .resizeFailed }
    )

    reconciler.apply([
      1: CGRect(x: 0, y: 0, width: 100, height: 100),
      2: CGRect(x: 100, y: 0, width: 100, height: 100),
    ])

    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: .zero))
    #expect(reconciler.shouldSuppressNotification(for: 2, actualFrame: .zero) == false)
  }

  @Test("apply: retries a successful mutation that did not reach its target")
  func applyRetriesIncompleteSuccessfulMutation() {
    let initialFrame = CGRect(x: 750, y: 400, width: 250, height: 400)
    let targetFrame = CGRect(x: 500, y: 400, width: 500, height: 400)
    var frame = initialFrame
    var mutationCount = 0
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in frame },
      frameMutation: { _, targetFrame, currentFrame in
        mutationCount += 1
        if mutationCount == 1 {
          frame = CGRect(origin: targetFrame.origin, size: currentFrame.size)
        } else {
          frame = targetFrame
        }
        return .success
      }
    )

    reconciler.apply([1: targetFrame])

    #expect(mutationCount == 2)
    #expect(frame == targetFrame)
  }

  @Test("shouldSuppressNotification: holds intermediate events and consumes the target")
  func shouldSuppressNotificationHoldsIntermediateEventsAndConsumesTarget() {
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in .zero },
      frameMutation: { _, _, _ in .success }
    )
    let target = CGRect(x: 100, y: 100, width: 400, height: 300)
    reconciler.apply([1: target])

    #expect(
      reconciler.shouldSuppressNotification(
        for: 1,
        actualFrame: CGRect(x: 0, y: 0, width: 400, height: 300)
      )
    )
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: .zero))
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: target))
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: target) == false)
  }
}
