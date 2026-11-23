import AppKit

@MainActor
final class WindowFrameReconciler {
  typealias CurrentFrameProvider = (CGWindowID) -> CGRect?

  private static let expectationLifetime = Duration.seconds(1)
  private static let animationFrameInterval = Duration.seconds(1.0 / 60)

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
      animations.removeAll()
      for (id, target) in targets { submitFrame(target, for: id, final: true) }
      updateScheduler()
    }
  }

  var animationEasing = AnimationEasing.easeOutQuad

  var animationEnabled: Bool { animationDuration > 0 && !reduceMotion() }

  var isIdle: Bool { animations.isEmpty && deliveries.isEmpty }

  var onInteractionEnded: () -> Void = {}

  /// Called when a window ends up at a different frame than its final requested one.
  var onFrameRefused: ((_ id: CGWindowID, _ target: CGRect, _ actual: CGRect) -> Void)?

  private let automaticallySchedule: Bool
  private let delivery: AnimationFrameDelivery
  private var deliveries = [CGWindowID: FrameDeliveryState]()
  private var interactingWindows = Set<CGWindowID>()
  private var interactionMonitor: Any?
  private var interactionCandidate: CGWindowID?
  private var interactionCandidateDragged = false
  private let terminalFailure: (CGWindowID) -> Void

  private var animations = [CGWindowID: FrameAnimation]()
  private var displayLink: AnimationDisplayLink?
  private let reduceMotion: () -> Bool
  private let currentFrame: CurrentFrameProvider
  private var pendingMutations = [CGWindowID: ExpectedFrameMutation]()

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

  func apply(
    _ targetFrames: [CGWindowID: CGRect],
    at now: ContinuousClock.Instant = .now,
    completion: (([CGWindowID: Bool]) -> Void)? = nil
  ) {
    if let completion {
      cancelAnimations(for: targetFrames.keys)
      let batch = FrameDeliveryBatch(ids: Set(targetFrames.keys), completion: completion)
      deliver(targetFrames, animated: animationEnabled, at: now, batch: batch)
    } else {
      deliver(targetFrames, animated: animationEnabled, at: now)
    }
  }

  func cancelAnimations(for windowIDs: some Sequence<CGWindowID>) {
    for windowID in windowIDs {
      deliveries.removeValue(forKey: windowID)?.generation.cancel()
      animations.removeValue(forKey: windowID)
      pendingMutations.removeValue(forKey: windowID)
    }
    stopSchedulerIfIdle()
    displayLink?.update(frames: animations.mapValues(\.target))
  }

  func prepareForSynchronousMutation(for windowID: CGWindowID) {
    cancelAnimations(for: [windowID])
    delivery.waitForPendingOperations(for: windowID)
  }

  func cancelAnimations() {
    cancelAnimations(for: Set(animations.keys).union(deliveries.keys))
  }

  func isAnimating(_ windowID: CGWindowID) -> Bool { animations[windowID] != nil }

  func isInteracting(_ windowID: CGWindowID) -> Bool { interactingWindows.contains(windowID) }

  func retainWindows(_ liveIDs: Set<CGWindowID>) {
    cancelAnimations(for: Set(animations.keys).union(deliveries.keys).subtracting(liveIDs))
    interactingWindows.formIntersection(liveIDs)
    if let id = interactionCandidate, !liveIDs.contains(id) {
      interactionCandidate = nil
      interactionCandidateDragged = false
    }
  }

  func advanceAnimations(
    at now: ContinuousClock.Instant = .now,
    windowIDs: Set<CGWindowID>? = nil,
    finishImmediately: Bool = false
  ) {
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

  func frames(for windowIDs: some Sequence<CGWindowID>) -> [CGWindowID: CGRect] {
    var framesByWindowID = [CGWindowID: CGRect]()
    for windowID in windowIDs {
      framesByWindowID[windowID] =
        deliveries[windowID]?.target ?? animations[windowID]?.target ?? currentFrame(windowID)
    }
    return framesByWindowID
  }

  func shouldSuppressNotification(for windowID: CGWindowID) -> Bool {
    shouldSuppressNotification(for: windowID) { currentFrame(windowID) }
  }

  func beginInteraction(for windowID: CGWindowID) {
    interactingWindows.insert(windowID)
    cancelAnimations(for: [windowID])
  }

  func pointerDown(on windowID: CGWindowID?) {
    interactionCandidate = windowID
    interactionCandidateDragged = false
  }

  func pointerDragged() {
    interactionCandidateDragged = interactionCandidate != nil
  }

  func endInteractions() {
    let wasInteracting = !interactingWindows.isEmpty
    interactionCandidate = nil
    interactionCandidateDragged = false
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
    at now: ContinuousClock.Instant,
    batch: FrameDeliveryBatch? = nil
  ) {
    for (id, target) in targets {
      guard !interactingWindows.contains(id) else { continue }
      if let existing = deliveries[id], existing.target == target,
        animated || existing.isFinal
      {
        continue
      }
      cancelAnimations(for: [id])
      let state = FrameDeliveryState(target: target, batch: batch)
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
            state.batch?.receive(id, verified: false)
            return
          }
          if frame == target {
            self.deliveries.removeValue(forKey: id)
            state.batch?.receive(id, verified: true)
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
    expectMutation(to: target, for: id)
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
        state.batch?.receive(id, verified: false)
        if let actual = result.frame { self.onFrameRefused?(id, target, actual) }
      } else if result.outcome == .verified {
        self.deliveries.removeValue(forKey: id)
        self.expectMutation(to: state.target, for: id, reachedTarget: true)
        state.batch?.receive(id, verified: true)
      }
    }
  }

  private func deliveryFailed(_ id: CGWindowID) {
    let target = deliveries[id]?.target
    cancelAnimations(for: [id])
    if let target {
      expectMutation(to: target, for: id)
    }
    terminalFailure(id)
  }

  private func stopSchedulerIfIdle() {
    guard animations.isEmpty else { return }
    displayLink?.stop()
    displayLink = nil
  }

  private func expectMutation(to target: CGRect, for id: CGWindowID, reachedTarget: Bool = false) {
    pendingMutations[id] = ExpectedFrameMutation(
      target: target,
      expiresAt: .now.advanced(by: Self.expectationLifetime),
      reachedTarget: reachedTarget
    )
  }

  private func shouldSuppressNotification(
    for windowID: CGWindowID,
    actualFrame: () -> CGRect?
  ) -> Bool {
    if interactingWindows.contains(windowID) { return true }
    if windowID == interactionCandidate, interactionCandidateDragged {
      beginInteraction(for: windowID)
      return true
    }
    if animations[windowID] != nil || deliveries[windowID] != nil { return true }
    expireExpectations()
    guard var expectation = pendingMutations[windowID] else { return false }

    let actualFrame = actualFrame()
    if let actualFrame, actualFrame.matches(expectation.target, tolerance: 1) {
      expectation.reachedTarget = true
      pendingMutations[windowID] = expectation
    } else if expectation.reachedTarget, actualFrame != nil {
      pendingMutations.removeValue(forKey: windowID)
      return false
    }

    return true
  }

  private func expireExpectations() {
    let now = ContinuousClock.now
    pendingMutations = pendingMutations.filter { $0.value.expiresAt > now }
  }

}

private struct ExpectedFrameMutation {
  let target: CGRect

  let expiresAt: ContinuousClock.Instant

  var reachedTarget = false
}

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

@MainActor
private final class FrameDeliveryState {
  let target: CGRect
  let batch: FrameDeliveryBatch?
  let generation = AnimationGeneration()
  var sequence: UInt64 = 0
  var isFinal = false

  init(target: CGRect, batch: FrameDeliveryBatch?) {
    self.target = target
    self.batch = batch
  }
}

@MainActor
private final class FrameDeliveryBatch {
  private var remaining: Set<CGWindowID>
  private var results = [CGWindowID: Bool]()
  private let completion: ([CGWindowID: Bool]) -> Void

  init(ids: Set<CGWindowID>, completion: @escaping ([CGWindowID: Bool]) -> Void) {
    remaining = ids
    self.completion = completion
  }

  func receive(_ id: CGWindowID, verified: Bool) {
    guard remaining.remove(id) != nil else { return }
    results[id] = verified
    if remaining.isEmpty { completion(results) }
  }
}
