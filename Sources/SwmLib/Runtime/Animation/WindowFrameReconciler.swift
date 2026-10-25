import AppKit

/// Applies calculated frames while tracking the Accessibility notifications they cause.
@MainActor
final class WindowFrameReconciler {
  typealias CurrentFrameProvider = (CGWindowID) -> CGRect?

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
      guard animationDuration == 0 else { return }
      let targets = animations.mapValues(\.target).merging(deliveries.mapValues(\.target)) {
        _,
        new in new
      }
      cancelAnimations()
      deliver(targets, animated: false, at: .now)
    }
  }

  var animationEasing = AnimationEasing.easeOutQuad

  var animationEnabled: Bool { animationDuration > 0 && !reduceMotion() }

  var isIdle: Bool { animations.isEmpty && deliveries.isEmpty }

  var onInteractionEnded: () -> Void = {}

  private let automaticallySchedule: Bool
  private let delivery: AnimationFrameDelivery
  private var deliveries = [CGWindowID: FrameDeliveryState]()
  private var interactingWindows = Set<CGWindowID>()
  private var interactionMonitor: Any?
  private var interactionCandidate: CGWindowID?
  private let terminalFailure: (CGWindowID) -> Void

  private var animations = [CGWindowID: FrameAnimation]()
  private var displayLink: AnimationDisplayLink?
  private let reduceMotion: () -> Bool
  private let currentFrame: CurrentFrameProvider
  private var pendingMutations = [CGWindowID: ExpectedFrameMutation]()

  /// Create a reconciler that reads frames directly and writes them through a delivery.
  init(
    currentFrame: @escaping CurrentFrameProvider,
    delivery: AnimationFrameDelivery,
    automaticallySchedule: Bool = true,
    terminalFailure: @escaping (CGWindowID) -> Void = {
      log("animation frame delivery failed window=\($0)", level: .warn)
    },
    reduceMotion: @escaping () -> Bool = {
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
  ) {
    self.automaticallySchedule = automaticallySchedule
    self.delivery = delivery
    self.terminalFailure = terminalFailure
    self.reduceMotion = reduceMotion
    self.currentFrame = currentFrame
  }

  isolated deinit {
    displayLink?.stop()
    for state in deliveries.values { state.generation.cancel() }
    if let interactionMonitor { NSEvent.removeMonitor(interactionMonitor) }
  }

  /// Animate a batch using the same clock, or deliver final frames when disabled.
  func apply(
    _ targetFrames: [CGWindowID: CGRect],
    at now: ContinuousClock.Instant = .now
  ) {
    deliver(targetFrames, animated: animationEnabled, at: now)
  }

  /// Drop queued work. An AX operation already started may still settle.
  func cancelAnimations(for windowIDs: some Sequence<CGWindowID>) {
    for windowID in windowIDs {
      deliveries.removeValue(forKey: windowID)?.generation.cancel()
      animations.removeValue(forKey: windowID)
      pendingMutations.removeValue(forKey: windowID)
    }
    stopSchedulerIfIdle()
    displayLink?.update(frames: animations.mapValues(\.target))
  }

  /// Preserve synchronous command ordering across an already-started asynchronous AX write.
  func prepareForSynchronousMutation(for windowID: CGWindowID) {
    cancelAnimations(for: [windowID])
    delivery.waitForPendingOperations(for: windowID)
  }

  /// Discard destinations calculated before a topology change.
  func cancelAnimations() {
    cancelAnimations(for: Set(animations.keys).union(deliveries.keys))
  }

  func isAnimating(_ windowID: CGWindowID) -> Bool { animations[windowID] != nil }

  func isInteracting(_ windowID: CGWindowID) -> Bool { interactingWindows.contains(windowID) }

  func retainWindows(_ liveIDs: Set<CGWindowID>) {
    cancelAnimations(for: Set(animations.keys).union(deliveries.keys).subtracting(liveIDs))
    interactingWindows.formIntersection(liveIDs)
    if let id = interactionCandidate, !liveIDs.contains(id) { interactionCandidate = nil }
  }

  /// Calculate each frame from elapsed time so delayed ticks do not slow the animation.
  func advanceAnimations(
    at now: ContinuousClock.Instant = .now,
    windowIDs: Set<CGWindowID>? = nil,
    finishImmediately: Bool = false
  ) {
    let tickStart = ContinuousClock.now
    defer { AnimationDiagnostics.shared.record("tick", since: tickStart) }
    var finished = Set<CGWindowID>()
    for (windowID, animation) in animations {
      if let windowIDs, !windowIDs.contains(windowID) { continue }
      let progress =
        finishImmediately || reduceMotion()
        ? 1
        : min(1, max(0, animation.startedAt.duration(to: now) / .seconds(1) / animation.duration))
      submitFrame(animation.frame(at: progress), for: windowID, final: progress == 1)
      if progress == 1 { finished.insert(windowID) }
    }
    for windowID in finished { animations.removeValue(forKey: windowID) }
    updateScheduler()
  }

  /// Return animation destinations, or current frames for windows that are not moving.
  func frames(for windowIDs: some Sequence<CGWindowID>) -> [CGWindowID: CGRect] {
    var framesByWindowID = [CGWindowID: CGRect]()
    for windowID in windowIDs {
      framesByWindowID[windowID] =
        deliveries[windowID]?.target ?? animations[windowID]?.target ?? currentFrame(windowID)
    }
    return framesByWindowID
  }

  /// Return whether a frame notification belongs to a pending SWM mutation.
  ///
  /// Suppress animation feedback, including duplicate notifications at the destination.
  func shouldSuppressNotification(for windowID: CGWindowID, actualFrame: CGRect?) -> Bool {
    if interactingWindows.contains(windowID) { return true }
    if animations[windowID] != nil || deliveries[windowID] != nil { return true }
    expireExpectations()
    guard var expectation = pendingMutations[windowID] else { return false }

    if let actualFrame, actualFrame.matches(expectation.target, tolerance: 1) {
      expectation.reachedTarget = true
      pendingMutations[windowID] = expectation
    } else if expectation.reachedTarget, actualFrame != nil {
      pendingMutations.removeValue(forKey: windowID)
      return false
    }

    return true
  }

  /// Read the current frame and return whether its notification belongs to SWM.
  func shouldSuppressNotification(for windowID: CGWindowID) -> Bool {
    if interactingWindows.contains(windowID) { return true }
    if animations[windowID] != nil || deliveries[windowID] != nil { return true }
    expireExpectations()
    guard pendingMutations[windowID] != nil else { return false }
    return shouldSuppressNotification(for: windowID, actualFrame: currentFrame(windowID))
  }

  /// Suspend the window being dragged until mouse-up, even during reconciliation.
  func beginInteraction(for windowID: CGWindowID) {
    interactingWindows.insert(windowID)
    cancelAnimations(for: [windowID])
  }

  func pointerDown(on windowID: CGWindowID?) {
    interactionCandidate = windowID
  }

  func pointerDragged() {
    guard let id = interactionCandidate, !interactingWindows.contains(id) else { return }
    beginInteraction(for: id)
  }

  func endInteractions() {
    let wasInteracting = !interactingWindows.isEmpty
    interactionCandidate = nil
    interactingWindows.removeAll()
    if wasInteracting { onInteractionEnded() }
  }

  func monitorInteractions(windowAtPoint: @escaping (CGPoint) -> CGWindowID?) {
    guard interactionMonitor == nil else { return }
    interactionMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
    ) { [weak self] event in
      MainActor.assumeIsolated {
        switch event.type {
        case .leftMouseDown:
          self?.pointerDown(on: event.cgEvent.flatMap { windowAtPoint($0.location) })
        case .leftMouseDragged:
          self?.pointerDragged()
        case .leftMouseUp:
          self?.endInteractions()
        default:
          break
        }
      }
    }
  }

  private func updateScheduler() {
    stopSchedulerIfIdle()
    guard !animations.isEmpty, automaticallySchedule else { return }
    if let displayLink {
      displayLink.update(frames: animations.mapValues(\.target))
      return
    }
    let link = AnimationDisplayLink(
      stalled: { [weak self] ids, time in
        self?.advanceAnimations(at: time, windowIDs: ids, finishImmediately: true)
      },
      tick: { [weak self] ids, time in
        self?.advanceAnimations(at: time, windowIDs: ids)
      }
    )
    link.update(frames: animations.mapValues(\.target))
    displayLink = link
  }

  private func deliver(
    _ targets: [CGWindowID: CGRect],
    animated: Bool,
    at now: ContinuousClock.Instant
  ) {
    for (id, target) in targets {
      guard !interactingWindows.contains(id) else { continue }
      if let existing = deliveries[id], existing.target == target,
        animated || existing.isFinal
      {
        continue
      }
      cancelAnimations(for: [id])
      let state = FrameDeliveryState(target: target)
      deliveries[id] = state
      if animated {
        let duration = animationDuration
        let easing = animationEasing
        delivery.submit(
          windowID: id,
          generation: state.generation,
          sequence: 0,
          target: nil,
          final: false
        ) { [weak self] result in
          guard let self, self.deliveries[id] === state, state.generation.isValid else { return }
          guard let frame = result.frame, result.outcome == .read else {
            self.deliveryFailed(id)
            return
          }
          if frame == target {
            self.deliveries.removeValue(forKey: id)
            return
          }
          self.animations[id] = FrameAnimation(
            start: frame,
            target: target,
            startedAt: max(now, .now),
            duration: duration,
            easing: easing
          )
          self.updateScheduler()
        }
      } else {
        submitFrame(target, for: id, final: true)
      }
    }
    updateScheduler()
  }

  private func submitFrame(_ target: CGRect, for id: CGWindowID, final: Bool) {
    guard let state = deliveries[id] else { return }
    state.sequence += 1
    state.isFinal = final
    pendingMutations[id] = ExpectedFrameMutation(
      target: target,
      expiresAt: .now.advanced(by: Self.expectationLifetime)
    )
    delivery.submit(
      windowID: id,
      generation: state.generation,
      sequence: state.sequence,
      target: target,
      final: final
    ) { [weak self] result in
      guard let self, self.deliveries[id] === state, state.generation.isValid,
        result.request.sequence == state.sequence
      else { return }
      if result.outcome == .failed {
        self.deliveryFailed(id)
      } else if result.outcome == .verified {
        self.deliveries.removeValue(forKey: id)
        self.pendingMutations[id] = ExpectedFrameMutation(
          target: state.target,
          expiresAt: .now.advanced(by: Self.expectationLifetime),
          reachedTarget: true
        )
      }
    }
  }

  private func deliveryFailed(_ id: CGWindowID) {
    let target = deliveries[id]?.target
    cancelAnimations(for: [id])
    if let target {
      // Failed or clamped writes can still emit delayed AX notifications. Do not let
      // those notifications restart the same failing reflow without a bound.
      pendingMutations[id] = ExpectedFrameMutation(
        target: target,
        expiresAt: .now.advanced(by: Self.expectationLifetime)
      )
    }
    terminalFailure(id)
  }

  private func stopSchedulerIfIdle() {
    guard animations.isEmpty else { return }
    displayLink?.stop()
    displayLink = nil
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

  /// Keep matching feedback suppressed after arrival, but allow a subsequent external move.
  var reachedTarget = false
}

/// Start frame, destination, and timing for one window.
private struct FrameAnimation {
  let start: CGRect
  let target: CGRect
  let startedAt: ContinuousClock.Instant
  let duration: Double
  let easing: AnimationEasing

  func frame(at progress: Double) -> CGRect {
    if progress >= 1 { return target }
    let eased = easing.value(at: progress)
    return CGRect(
      x: start.minX + (target.minX - start.minX) * eased,
      y: start.minY + (target.minY - start.minY) * eased,
      width: start.width + (target.width - start.width) * eased,
      height: start.height + (target.height - start.height) * eased
    )
  }
}

/// Requested destination and newest pending submission, retained through final verification.
@MainActor
private final class FrameDeliveryState {
  let target: CGRect
  let generation = AnimationGeneration()
  var sequence: UInt64 = 0
  var isFinal = false

  init(target: CGRect) { self.target = target }
}
