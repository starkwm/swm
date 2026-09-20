import AppKit
import Testing

@testable import SwmLib

@MainActor
@Suite("Animation frame delivery")
struct AnimationFrameDeliveryTests {
  @Test("blocked apps do not block other apps; pending targets coalesce and finals survive")
  func independentApplicationsAndCoalescing() async throws {
    let slow = AnimationTestApp(processID: 1)
    let fast = AnimationTestApp(processID: 2)
    slow.blockNextWrite()
    defer { slow.release() }
    let delivery = AnimationFrameDelivery { id in
      (id == 1 ? slow : fast).backend(for: id)
    }
    let generation = AnimationGeneration()
    var completed = [UInt64]()
    delivery.submit(
      windowID: 1,
      generation: generation,
      sequence: 1,
      target: rect(10),
      final: false
    ) {
      completed.append($0.request.sequence)
    }
    try await waitUntil { slow.writeCount == 1 }
    for sequence in 2...100 {
      delivery.submit(
        windowID: 1,
        generation: generation,
        sequence: UInt64(sequence),
        target: rect(Double(sequence)),
        final: sequence == 100
      ) { completed.append($0.request.sequence) }
    }
    var fastFinished = false
    delivery.submit(
      windowID: 2,
      generation: AnimationGeneration(),
      sequence: 1,
      target: rect(200),
      final: true
    ) {
      fastFinished = $0.outcome == .verified
    }
    try await waitUntil { fastFinished }
    #expect(slow.writeCount == 1)
    slow.release()
    try await waitUntil { completed.contains(100) }
    #expect(slow.frame == rect(100))
    #expect(slow.writeCount == 2)
    #expect(completed == [1, 100])
  }

  @Test("windows in the same app are serialized and obsolete queued generations are discarded")
  func serializedWindows() async throws {
    let app = AnimationTestApp(processID: 1)
    app.blockNextWrite()
    defer { app.release() }
    let delivery = AnimationFrameDelivery { app.backend(for: $0) }
    delivery.submit(
      windowID: 1,
      generation: AnimationGeneration(),
      sequence: 1,
      target: rect(10),
      final: false
    ) { _ in }
    try await waitUntil { app.writeCount == 1 }
    let obsolete = AnimationGeneration()
    var stale = false
    delivery.submit(windowID: 2, generation: obsolete, sequence: 1, target: rect(20), final: true) {
      _ in stale = true
    }
    obsolete.cancel()
    var finished = false
    delivery.submit(
      windowID: 3,
      generation: AnimationGeneration(),
      sequence: 1,
      target: rect(30),
      final: true
    ) { _ in finished = true }
    #expect(app.writeCount == 1)
    app.release()
    try await waitUntil { finished }
    #expect(!stale)
    #expect(app.writeCount == 2)
    #expect(app.frame(for: 1) == rect(10))
    #expect(app.frame(for: 2) == rect(0))
    #expect(app.frame(for: 3) == rect(30))
  }

  @Test("started writes may finish, but cancelled completions cannot replace newer intent")
  func cancellationDuringWrite() async throws {
    let app = AnimationTestApp(processID: 1)
    app.blockNextWrite()
    defer { app.release() }
    let delivery = AnimationFrameDelivery { _ in app.backend }
    let old = AnimationGeneration()
    var staleCompletion = false
    delivery.submit(windowID: 1, generation: old, sequence: 1, target: rect(10), final: true) { _ in
      staleCompletion = true
    }
    try await waitUntil { app.writeCount == 1 }
    old.cancel()
    var freshCompletion = false
    delivery.submit(
      windowID: 1,
      generation: AnimationGeneration(),
      sequence: 1,
      target: rect(200),
      final: true
    ) {
      freshCompletion = $0.outcome == .verified
    }
    app.release()
    try await waitUntil { freshCompletion }
    #expect(!staleCompletion)
    #expect(app.frame == rect(200))
    #expect(app.beginCount == app.endCount)
  }

  @Test("accepted geometry avoids intermediate reads and final settlement retries only once")
  func cachedGeometryAndSettlement() async throws {
    let app = AnimationTestApp(processID: 1)
    let delivery = AnimationFrameDelivery { _ in app.backend }
    let generation = AnimationGeneration()
    var last: AnimationFrameCompletion?
    delivery.submit(windowID: 1, generation: generation, sequence: 0, target: nil, final: false) {
      last = $0
    }
    try await waitUntil { last?.request.sequence == 0 }
    for sequence in 1...3 {
      delivery.submit(
        windowID: 1,
        generation: generation,
        sequence: UInt64(sequence),
        target: rect(Double(sequence * 10)),
        final: false
      ) { last = $0 }
      try await waitUntil { last?.request.sequence == UInt64(sequence) }
    }
    #expect(app.readCount == 1)
    app.clampWrites = true
    delivery.submit(
      windowID: 1,
      generation: generation,
      sequence: 4,
      target: rect(100),
      final: true
    ) { last = $0 }
    try await waitUntil { last?.request.sequence == 4 }
    #expect(last?.outcome == .failed)
    #expect(app.writeCount == 5)
    #expect(app.readCount == 4)
    #expect(app.beginCount == app.endCount)
  }

  @Test("final delivery compares actual geometry before submitting the exact target")
  func exactFinalTarget() async throws {
    let app = AnimationTestApp(processID: 1)
    let delivery = AnimationFrameDelivery { _ in app.backend }
    let generation = AnimationGeneration()
    var last: AnimationFrameCompletion?
    delivery.submit(
      windowID: 1,
      generation: generation,
      sequence: 1,
      target: rect(100),
      final: false
    ) { last = $0 }
    try await waitUntil { last != nil }
    app.frame = rect(99.75)
    delivery.submit(
      windowID: 1,
      generation: generation,
      sequence: 2,
      target: rect(100),
      final: true
    ) { last = $0 }
    try await waitUntil { last?.request.sequence == 2 }
    #expect(last?.outcome == .verified)
    #expect(app.frame == rect(100))
  }

  @Test("retargeting reads actual geometry after started work and retains pending destinations")
  func retargeting() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeReconciler(app)
    reconciler.animationDuration = 1
    reconciler.animationEasing = .linear
    let start = ContinuousClock.now.advanced(by: .seconds(10))
    reconciler.apply([1: rect(100)], at: start)
    #expect(reconciler.frames(for: [1])[1] == rect(100))
    try await waitUntil { reconciler.isAnimating(1) }
    app.blockNextWrite()
    defer { app.release() }
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(500)))
    try await waitUntil { app.writeCount == 1 }
    reconciler.apply([1: rect(200)], at: start)
    #expect(reconciler.frames(for: [1])[1] == rect(200))
    app.frame = rect(25)
    app.release()
    try await waitUntil { reconciler.isAnimating(1) && app.readCount == 2 }
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(500)))
    // The started AX operation lands at 50 after cancellation. Retarget from that
    // actual result, not the frame observed while the old operation was blocked.
    try await waitUntil { app.frame == rect(125) }
    reconciler.advanceAnimations(at: start.advanced(by: .seconds(1)))
    try await waitUntil { reconciler.isIdle }
    #expect(app.frame == rect(200))
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: rect(200)))
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: rect(300)))
  }

  @Test(
    "final writes settle after scheduling stops, including disabling and Reduce Motion",
    arguments: [0, 1, 2]
  )
  func finalDelivery(mode: Int) async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeReconciler(app, reduceMotion: { mode == 2 })
    reconciler.animationDuration = 1
    let start = ContinuousClock.now
    reconciler.apply([1: rect(100)], at: start)
    if mode != 2 {
      try await waitUntil { reconciler.isAnimating(1) }
      if mode == 0 {
        reconciler.animationDuration = 0
      } else {
        reconciler.advanceAnimations(at: start.advanced(by: .seconds(2)))
      }
    }
    try await waitUntil { reconciler.isIdle }
    #expect(app.frame == rect(100))
  }

  @Test("interaction and vanished windows cancel pending reads and prevent restart")
  func interactionAndDestruction() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeReconciler(app)
    reconciler.animationDuration = 1
    reconciler.apply([1: rect(100)])
    reconciler.beginInteraction(for: 1)
    reconciler.apply([1: rect(200)])
    #expect(reconciler.isIdle)
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: rect(20)))
    reconciler.endInteractions()
    reconciler.apply([1: rect(300)])
    reconciler.retainWindows([])
    try await Task.sleep(for: .milliseconds(20))
    #expect(reconciler.isIdle)
    #expect(app.writeCount == 0)
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: rect(20)))
  }

  @Test("terminal failures stop delivery and suppress their delayed feedback")
  func terminalFailure() async throws {
    let app = AnimationTestApp(processID: 1)
    app.clampWrites = true
    var failures = [CGWindowID]()
    let reconciler = makeReconciler(app, terminalFailure: { failures.append($0) })
    reconciler.apply([1: rect(100)])
    try await waitUntil { reconciler.isIdle }
    #expect(failures == [1])
    #expect(app.writeCount == 2)
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: app.frame))
  }

  @Test("synchronous commands wait for cancelled writes and enhanced-UI restoration")
  func synchronousCommandOrdering() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeReconciler(app)
    app.blockNextWrite()
    defer { app.release() }
    reconciler.apply([1: rect(100)])
    try await waitUntil { app.writeCount == 1 }
    Task.detached { app.release() }
    reconciler.prepareForSynchronousMutation(for: 1)
    #expect(app.frame == rect(100))
    #expect(app.beginCount == app.endCount)
    // Model the subsequent synchronous command, after the old AX call has settled.
    app.frame = rect(200)
    #expect(reconciler.isIdle)
    await Task.yield()
    #expect(app.frame == rect(200))
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: app.frame))
  }

  @Test("repeating an immediate target preserves its in-flight final write")
  func duplicateImmediateTarget() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeReconciler(app)
    app.blockNextWrite()
    defer { app.release() }
    reconciler.apply([1: rect(100)])
    try await waitUntil { app.writeCount == 1 }
    for _ in 0..<10 { reconciler.apply([1: rect(100)]) }
    app.release()
    try await waitUntil { reconciler.isIdle }
    #expect(app.frame == rect(100))
    #expect(app.writeCount == 1)
  }

  @Test("clicks preserve animation; a drag suspends writes and reconciles once on release")
  func pointerInteraction() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeReconciler(app)
    var ended = 0
    reconciler.onInteractionEnded = { ended += 1 }
    reconciler.animationDuration = 1
    reconciler.apply([1: rect(100)])
    try await waitUntil { reconciler.isAnimating(1) }
    reconciler.pointerDown(on: 1)
    reconciler.endInteractions()
    #expect(reconciler.isAnimating(1))
    #expect(ended == 0)
    reconciler.pointerDown(on: 1)
    reconciler.pointerDragged()
    reconciler.pointerDragged()
    #expect(reconciler.isIdle)
    reconciler.apply([1: rect(200)])
    #expect(reconciler.isIdle)
    reconciler.endInteractions()
    reconciler.endInteractions()
    #expect(ended == 1)
  }

  @Test("failed settlement notifications do not immediately restart a failing reflow")
  func failedSettlementFeedback() async throws {
    let app = AnimationTestApp(processID: 1)
    app.clampWrites = true
    let reconciler = makeReconciler(app)
    var snapshots = 0
    let tiling = makeTiling(
      windows: {
        snapshots += 1
        return [window(id: 1)]
      },
      memberships: { [1: [10]] },
      frameReconciler: reconciler
    )
    tiling.initialize()
    let before = snapshots
    reconciler.apply([1: rect(100)])
    try await waitUntil { reconciler.isIdle }
    for _ in 0..<10 { tiling.windowFrameDidChange(1) }
    #expect(snapshots == before)
    #expect(app.writeCount == 2)
  }

  @Test("presentation time conversion bounds stale and invalid timestamps")
  func timingConversion() {
    let now = ContinuousClock.now
    #expect(
      AnimationDisplayLink.presentationTime(targetTimestamp: 10.01, mediaTime: 10, now: now) > now
    )
    #expect(
      AnimationDisplayLink.presentationTime(targetTimestamp: 9, mediaTime: 10, now: now) == now
    )
    #expect(
      AnimationDisplayLink.presentationTime(targetTimestamp: .nan, mediaTime: 10, now: now) == now
    )
    #expect(
      AnimationDisplayLink.presentationTime(targetTimestamp: 100, mediaTime: 10, now: now)
        == now.advanced(by: .seconds(1.0 / 30))
    )
  }

  private func rect(_ x: Double) -> CGRect { CGRect(x: x, y: 0, width: 100, height: 100) }

  private func makeReconciler(
    _ app: AnimationTestApp,
    reduceMotion: @escaping () -> Bool = { false },
    terminalFailure: @escaping (CGWindowID) -> Void = { _ in }
  ) -> WindowFrameReconciler {
    WindowFrameReconciler(
      currentFrame: { _ in app.frame },
      frameMutation: { _, _, _ in
        Issue.record("synchronous mutation")
        return nil
      },
      delivery: AnimationFrameDelivery { _ in app.backend },
      automaticallySchedule: false,
      terminalFailure: terminalFailure,
      reduceMotion: reduceMotion
    )
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !condition(), ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(1))
    }
    try #require(condition())
  }
}
