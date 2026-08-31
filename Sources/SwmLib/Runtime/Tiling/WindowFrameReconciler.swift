import CoreGraphics

/// Applies calculated frames while tracking the Accessibility notifications they cause.
@MainActor
final class WindowFrameReconciler {
  typealias CurrentFrameProvider = (CGWindowID) -> CGRect?
  typealias FrameMutation = (CGWindowID, CGRect, CGRect) -> WindowFrameMutationResult?

  private static let expectationLifetime = Duration.seconds(1)
  private static let tolerance = CGFloat(1)

  private let currentFrame: CurrentFrameProvider
  private let frameMutation: FrameMutation
  private var pendingMutations = [CGWindowID: ExpectedFrameMutation]()

  /// Create a reconciler backed by frame access and mutation operations.
  init(
    currentFrame: @escaping CurrentFrameProvider,
    frameMutation: @escaping FrameMutation
  ) {
    self.currentFrame = currentFrame
    self.frameMutation = frameMutation
  }

  /// Apply only changed frames after recording every feedback expectation.
  func apply(_ targetFrames: [CGWindowID: CGRect]) {
    expireExpectations()

    var changedFrames = [CGWindowID: FrameApplicationTarget]()
    for (windowID, targetFrame) in targetFrames {
      guard let currentFrame = currentFrame(windowID) else {
        changedFrames[windowID] = FrameApplicationTarget(
          currentFrame: nil,
          targetFrame: targetFrame
        )
        continue
      }
      guard !framesMatch(currentFrame, targetFrame) else { continue }
      changedFrames[windowID] = FrameApplicationTarget(
        currentFrame: currentFrame,
        targetFrame: targetFrame
      )
    }

    guard !changedFrames.isEmpty else { return }

    let expiresAt = ContinuousClock.now.advanced(by: Self.expectationLifetime)

    for (windowID, target) in changedFrames {
      pendingMutations[windowID] = ExpectedFrameMutation(
        target: target.targetFrame,
        expiresAt: expiresAt
      )
    }

    for windowID in changedFrames.keys.sorted() {
      guard let target = changedFrames[windowID] else { continue }
      guard let currentFrame = target.currentFrame else {
        pendingMutations.removeValue(forKey: windowID)
        continue
      }

      guard let result = frameMutation(windowID, target.targetFrame, currentFrame) else {
        pendingMutations.removeValue(forKey: windowID)
        continue
      }

      // Some apps clamp a resize at the old origin before accepting the accompanying move.
      if result == .success,
        let appliedFrame = self.currentFrame(windowID),
        !framesMatch(appliedFrame, target.targetFrame)
      {
        _ = frameMutation(windowID, target.targetFrame, appliedFrame)
      }
    }
  }

  /// Return current frames for the requested windows when Accessibility can read them.
  func frames(for windowIDs: some Sequence<CGWindowID>) -> [CGWindowID: CGRect] {
    var framesByWindowID = [CGWindowID: CGRect]()
    for windowID in windowIDs {
      framesByWindowID[windowID] = currentFrame(windowID)
    }
    return framesByWindowID
  }

  /// Return whether a frame notification belongs to a pending SWM mutation.
  ///
  /// Intermediate move or resize notifications remain suppressed until the target frame arrives
  /// or the expectation expires.
  func shouldSuppressNotification(for windowID: CGWindowID, actualFrame: CGRect?) -> Bool {
    expireExpectations()
    guard let expectation = pendingMutations[windowID] else { return false }

    if let actualFrame, framesMatch(actualFrame, expectation.target) {
      pendingMutations.removeValue(forKey: windowID)
    }

    return true
  }

  /// Read the current frame and return whether its notification belongs to SWM.
  func shouldSuppressNotification(for windowID: CGWindowID) -> Bool {
    shouldSuppressNotification(for: windowID, actualFrame: currentFrame(windowID))
  }

  /// Remove expectations whose bounded suppression interval has elapsed.
  private func expireExpectations() {
    let now = ContinuousClock.now
    pendingMutations = pendingMutations.filter { $0.value.expiresAt > now }
  }

  /// Compare complete frames using the configured point tolerance.
  private func framesMatch(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
    abs(lhs.minX - rhs.minX) <= Self.tolerance
      && abs(lhs.minY - rhs.minY) <= Self.tolerance
      && abs(lhs.width - rhs.width) <= Self.tolerance
      && abs(lhs.height - rhs.height) <= Self.tolerance
  }
}

/// Expected frame notification registered before an Accessibility mutation.
private struct ExpectedFrameMutation {
  /// Final target frame.
  let target: CGRect

  /// Time after which notifications are no longer attributed to the mutation.
  let expiresAt: ContinuousClock.Instant
}

/// Current and target frame retained while a batch is applied.
private struct FrameApplicationTarget {
  let currentFrame: CGRect?
  let targetFrame: CGRect
}
