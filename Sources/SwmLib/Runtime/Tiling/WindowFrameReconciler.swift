import AppKit

/// Applies calculated frames while tracking the Accessibility notifications they cause.
@MainActor
final class WindowFrameReconciler {
  typealias CurrentFrameProvider = (CGWindowID) -> CGRect?
  typealias FrameMutation = (CGWindowID, CGRect, CGRect) -> WindowFrameMutationResult?

  private static let expectationLifetime = Duration.seconds(1)
  private static let animationFrameInterval = Duration.seconds(1.0 / 60)

  /// Keep a steady cadence and skip missed frames instead of queuing catch-up updates.
  static func nextAnimationDeadline(
    after previous: ContinuousClock.Instant,
    now: ContinuousClock.Instant
  ) -> ContinuousClock.Instant {
    let intervals = max(1, Int(previous.duration(to: now) / animationFrameInterval) + 1)
    return previous.advanced(by: animationFrameInterval * intervals)
  }

  var animationDuration: Double = 0 {
    didSet {
      if animationDuration == 0 {
        let targets = animations.mapValues(\.target)
        cancelAnimations()
        applyImmediately(targets, exactWindowIDs: Set(targets.keys))
      }
    }
  }

  var animationEnabled: Bool { animationDuration > 0 && !reduceMotion() }

  private var animations = [CGWindowID: FrameAnimation]()
  private var animationTask: Task<Void, Never>?
  private let reduceMotion: () -> Bool
  private let currentFrame: CurrentFrameProvider
  private let frameMutation: FrameMutation
  private var pendingMutations = [CGWindowID: ExpectedFrameMutation]()

  /// Create a reconciler backed by frame access and mutation operations.
  init(
    currentFrame: @escaping CurrentFrameProvider,
    frameMutation: @escaping FrameMutation,
    reduceMotion: @escaping () -> Bool = {
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
  ) {
    self.reduceMotion = reduceMotion
    self.currentFrame = currentFrame
    self.frameMutation = frameMutation
  }

  deinit {
    animationTask?.cancel()
  }

  /// Animate a batch using the same clock, or apply it immediately when disabled.
  func apply(
    _ targetFrames: [CGWindowID: CGRect],
    at now: ContinuousClock.Instant = .now
  ) {
    guard animationEnabled else {
      for windowID in targetFrames.keys { animations.removeValue(forKey: windowID) }
      applyImmediately(targetFrames)
      return
    }

    for (windowID, target) in targetFrames {
      if animations[windowID]?.target == target { continue }
      animations.removeValue(forKey: windowID)
      guard let start = currentFrame(windowID), start != target else {
        continue
      }
      animations[windowID] = FrameAnimation(
        start: start,
        target: target,
        startedAt: now,
        duration: animationDuration
      )
    }
    guard !animations.isEmpty, animationTask == nil else { return }
    animationTask = Task { [weak self] in
      let clock = ContinuousClock()
      var deadline = clock.now
      while !Task.isCancelled {
        deadline = Self.nextAnimationDeadline(after: deadline, now: clock.now)
        do { try await clock.sleep(until: deadline, tolerance: .zero) } catch { return }
        guard !Task.isCancelled, let self else { return }
        self.advanceAnimations()
        if self.animations.isEmpty {
          self.animationTask = nil
          return
        }
      }
    }
  }

  /// Leave cancelled windows at their current frames.
  func cancelAnimations(for windowIDs: some Sequence<CGWindowID>) {
    for windowID in windowIDs {
      animations.removeValue(forKey: windowID)
      pendingMutations.removeValue(forKey: windowID)
    }
    if animations.isEmpty {
      animationTask?.cancel()
      animationTask = nil
    }
  }

  /// Discard destinations calculated before a topology change.
  func cancelAnimations() {
    cancelAnimations(for: Array(animations.keys))
  }

  /// Calculate each frame from elapsed time so delayed ticks do not slow the animation.
  func advanceAnimations(at now: ContinuousClock.Instant = .now) {
    var frames = [CGWindowID: CGRect]()
    var currentFrames = [CGWindowID: CGRect]()
    var finished = Set<CGWindowID>()
    for (windowID, animation) in animations {
      guard let current = currentFrame(windowID) else {
        finished.insert(windowID)
        pendingMutations.removeValue(forKey: windowID)
        continue
      }
      let elapsed = animation.startedAt.duration(to: now)
      let progress = min(1, max(0, elapsed / .seconds(1) / animation.duration))
      frames[windowID] = animation.frame(at: progress)
      currentFrames[windowID] = current
      if progress == 1 { finished.insert(windowID) }
    }
    applyImmediately(frames, currentFrames: currentFrames, exactWindowIDs: finished)
    for windowID in finished { animations.removeValue(forKey: windowID) }
  }

  /// Return animation destinations, or current frames for windows that are not moving.
  func frames(for windowIDs: some Sequence<CGWindowID>) -> [CGWindowID: CGRect] {
    var framesByWindowID = [CGWindowID: CGRect]()
    for windowID in windowIDs {
      framesByWindowID[windowID] = animations[windowID]?.target ?? currentFrame(windowID)
    }
    return framesByWindowID
  }

  /// Return whether a frame notification belongs to a pending SWM mutation.
  ///
  /// Suppress notifications throughout animation and until the last frame arrives or times out.
  func shouldSuppressNotification(for windowID: CGWindowID, actualFrame: CGRect?) -> Bool {
    if animations[windowID] != nil { return true }
    expireExpectations()
    guard let expectation = pendingMutations[windowID] else { return false }

    if let actualFrame, actualFrame.matches(expectation.target, tolerance: 1) {
      pendingMutations.removeValue(forKey: windowID)
    }

    return true
  }

  /// Read the current frame and return whether its notification belongs to SWM.
  func shouldSuppressNotification(for windowID: CGWindowID) -> Bool {
    if animations[windowID] != nil { return true }
    expireExpectations()
    guard pendingMutations[windowID] != nil else { return false }
    return shouldSuppressNotification(for: windowID, actualFrame: currentFrame(windowID))
  }

  /// Record expected notifications before moving any windows.
  private func applyImmediately(
    _ targetFrames: [CGWindowID: CGRect],
    currentFrames: [CGWindowID: CGRect]? = nil,
    exactWindowIDs: Set<CGWindowID> = []
  ) {
    expireExpectations()

    var changedFrames = [CGWindowID: FrameApplicationTarget]()
    for (windowID, targetFrame) in targetFrames {
      let current =
        if let currentFrames { currentFrames[windowID] } else { currentFrame(windowID) }
      guard let currentFrame = current else {
        pendingMutations.removeValue(forKey: windowID)
        continue
      }
      let tolerance: CGFloat = exactWindowIDs.contains(windowID) ? 0 : 1
      guard !currentFrame.matches(targetFrame, tolerance: tolerance) else { continue }
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
      guard let result = frameMutation(windowID, target.targetFrame, target.currentFrame) else {
        pendingMutations.removeValue(forKey: windowID)
        continue
      }

      // Some apps clamp a resize at the old origin before accepting the accompanying move.
      // Intermediate animation frames will be superseded on the next tick.
      if currentFrames == nil || exactWindowIDs.contains(windowID), result == .success,
        let appliedFrame = self.currentFrame(windowID),
        !appliedFrame.matches(target.targetFrame, tolerance: 1)
      {
        _ = frameMutation(windowID, target.targetFrame, appliedFrame)
      }
    }
  }

  /// Stop suppressing notifications after their timeout.
  private func expireExpectations() {
    let now = ContinuousClock.now
    pendingMutations = pendingMutations.filter { $0.value.expiresAt > now }
  }

}

/// Expected frame notification registered before an Accessibility mutation.
private struct ExpectedFrameMutation {
  /// Last requested frame.
  let target: CGRect

  /// When to stop suppressing notifications.
  let expiresAt: ContinuousClock.Instant
}

/// Current and target frame retained while a batch is applied.
private struct FrameApplicationTarget {
  let currentFrame: CGRect
  let targetFrame: CGRect
}

/// Start frame, destination, and timing for one window.
private struct FrameAnimation {
  let start: CGRect
  let target: CGRect
  let startedAt: ContinuousClock.Instant
  let duration: Double

  func frame(at progress: Double) -> CGRect {
    if progress >= 1 { return target }
    let eased = 1 - (1 - progress) * (1 - progress)
    return CGRect(
      x: start.minX + (target.minX - start.minX) * eased,
      y: start.minY + (target.minY - start.minY) * eased,
      width: start.width + (target.width - start.width) * eased,
      height: start.height + (target.height - start.height) * eased
    )
  }
}
