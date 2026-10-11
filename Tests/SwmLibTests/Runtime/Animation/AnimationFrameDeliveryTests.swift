import AppKit
import Testing

@testable import SwmLib

@MainActor
@Suite("AnimationFrameDelivery")
struct AnimationFrameDeliveryTests {
  @Test("submit: isolates apps and coalesces pending targets while preserving final writes")
  func submitIsolatesAppsAndCoalescesPendingTargetsWhilePreservingFinalWrites() async throws {
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
      target: animationFrame(10),
      final: false
    ) {
      completed.append($0.request.sequence)
    }
    try await waitForAnimation { slow.writeCount == 1 }
    for sequence in 2...100 {
      delivery.submit(
        windowID: 1,
        generation: generation,
        sequence: UInt64(sequence),
        target: animationFrame(Double(sequence)),
        final: sequence == 100
      ) { completed.append($0.request.sequence) }
    }
    var fastFinished = false
    delivery.submit(
      windowID: 2,
      generation: AnimationGeneration(),
      sequence: 1,
      target: animationFrame(200),
      final: true
    ) {
      fastFinished = $0.outcome == .verified
    }
    try await waitForAnimation { fastFinished }
    #expect(slow.writeCount == 1)
    slow.release()
    try await waitForAnimation { completed.contains(100) }
    #expect(slow.frame == animationFrame(100))
    #expect(slow.writeCount == 2)
    #expect(completed == [1, 100])
  }

  @Test("submit: serializes windows within an app and discards obsolete generations")
  func submitSerializesWindowsWithinAnAppAndDiscardsObsoleteGenerations() async throws {
    let app = AnimationTestApp(processID: 1)
    app.blockNextWrite()
    defer { app.release() }
    let delivery = AnimationFrameDelivery { app.backend(for: $0) }
    delivery.submit(
      windowID: 1,
      generation: AnimationGeneration(),
      sequence: 1,
      target: animationFrame(10),
      final: false
    ) { _ in }
    try await waitForAnimation { app.writeCount == 1 }
    let obsolete = AnimationGeneration()
    var stale = false
    delivery.submit(
      windowID: 2,
      generation: obsolete,
      sequence: 1,
      target: animationFrame(20),
      final: true
    ) {
      _ in stale = true
    }
    obsolete.cancel()
    var finished = false
    delivery.submit(
      windowID: 3,
      generation: AnimationGeneration(),
      sequence: 1,
      target: animationFrame(30),
      final: true
    ) { _ in finished = true }
    #expect(app.writeCount == 1)
    app.release()
    try await waitForAnimation { finished }
    #expect(!stale)
    #expect(app.writeCount == 2)
    #expect(app.frame(for: 1) == animationFrame(10))
    #expect(app.frame(for: 2) == animationFrame(0))
    #expect(app.frame(for: 3) == animationFrame(30))
  }

  @Test("submit: discards cancelled completions after started writes")
  func submitDiscardsCancelledCompletionsAfterStartedWrites() async throws {
    let app = AnimationTestApp(processID: 1)
    app.blockNextWrite()
    defer { app.release() }
    let delivery = AnimationFrameDelivery { _ in app.backend }
    let old = AnimationGeneration()
    var staleCompletion = false
    delivery.submit(
      windowID: 1,
      generation: old,
      sequence: 1,
      target: animationFrame(10),
      final: true
    ) { _ in
      staleCompletion = true
    }
    try await waitForAnimation { app.writeCount == 1 }
    old.cancel()
    var freshCompletion = false
    delivery.submit(
      windowID: 1,
      generation: AnimationGeneration(),
      sequence: 1,
      target: animationFrame(200),
      final: true
    ) {
      freshCompletion = $0.outcome == .verified
    }
    app.release()
    try await waitForAnimation { freshCompletion }
    #expect(!staleCompletion)
    #expect(app.frame == animationFrame(200))
    #expect(app.beginCount == app.endCount)
  }

  @Test("submit: caches intermediate geometry and bounds final correction attempts")
  func submitCachesIntermediateGeometryAndBoundsFinalCorrectionAttempts() async throws {
    let app = AnimationTestApp(processID: 1)
    let delivery = AnimationFrameDelivery { _ in app.backend }
    let generation = AnimationGeneration()
    var last: AnimationFrameCompletion?
    delivery.submit(windowID: 1, generation: generation, sequence: 0, target: nil, final: false) {
      last = $0
    }
    try await waitForAnimation { last?.request.sequence == 0 }
    for sequence in 1...3 {
      delivery.submit(
        windowID: 1,
        generation: generation,
        sequence: UInt64(sequence),
        target: animationFrame(Double(sequence * 10)),
        final: false
      ) { last = $0 }
      try await waitForAnimation { last?.request.sequence == UInt64(sequence) }
    }
    #expect(app.readCount == 1)
    app.clampWrites = true
    delivery.submit(
      windowID: 1,
      generation: generation,
      sequence: 4,
      target: animationFrame(100),
      final: true
    ) { last = $0 }
    try await waitForAnimation { last?.request.sequence == 4 }
    #expect(last?.outcome == .failed)
    #expect(app.writeCount == 5)
    #expect(app.readCount == 4)
    #expect(app.beginCount == app.endCount)
  }

  @Test("submit: compares actual geometry before writing the exact final target")
  func submitComparesActualGeometryBeforeWritingTheExactFinalTarget() async throws {
    let app = AnimationTestApp(processID: 1)
    let delivery = AnimationFrameDelivery { _ in app.backend }
    let generation = AnimationGeneration()
    var last: AnimationFrameCompletion?
    delivery.submit(
      windowID: 1,
      generation: generation,
      sequence: 1,
      target: animationFrame(100),
      final: false
    ) { last = $0 }
    try await waitForAnimation { last != nil }
    app.frame = animationFrame(99.75)
    delivery.submit(
      windowID: 1,
      generation: generation,
      sequence: 2,
      target: animationFrame(100),
      final: true
    ) { last = $0 }
    try await waitForAnimation { last?.request.sequence == 2 }
    #expect(last?.outcome == .verified)
    #expect(app.frame == animationFrame(100))
  }

}
