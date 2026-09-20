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

  private func rect(_ x: Double) -> CGRect { CGRect(x: x, y: 0, width: 100, height: 100) }

  private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !condition(), ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(1))
    }
    try #require(condition())
  }
}
