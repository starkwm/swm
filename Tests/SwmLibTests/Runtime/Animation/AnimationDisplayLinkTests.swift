import AppKit
import Testing

@testable import SwmLib

@MainActor
@Suite("Animation display links")
struct AnimationDisplayLinkTests {
  @Test("each display advances only its windows and idle links stop")
  func displayLocalTicks() {
    var created = [UInt32: TestScreenLink]()
    let displays = [
      display(1, x: 0, created: { created[1] = $0 }),
      display(2, x: 1000, created: { created[2] = $0 }),
    ]
    var ticks = [Set<CGWindowID>]()
    let scheduler = AnimationDisplayLink(
      displays: { displays },
      tick: { ids, _ in ticks.append(ids) }
    )
    scheduler.update(frames: [10: frame(0), 20: frame(1100)])
    created[1]?.fire()
    created[2]?.fire()
    #expect(ticks == [[10], [20]])
    scheduler.update(frames: [20: frame(1100)])
    #expect(created[1]?.stopped == true)
    #expect(created[2]?.stopped == false)
    scheduler.stop()
    #expect(created[2]?.stopped == true)
  }

  @Test("disconnect migrates work and callbacks from retired links cannot tick new sessions")
  func displayChanges() throws {
    var created = [UInt32: TestScreenLink]()
    let first = display(1, x: 0, created: { created[1] = $0 })
    let second = display(2, x: 1000, created: { created[2] = $0 })
    var displays = [first, second]
    var ticks = [Set<CGWindowID>]()
    let scheduler = AnimationDisplayLink(
      displays: { displays },
      tick: { ids, _ in ticks.append(ids) }
    )
    scheduler.update(frames: [10: frame(0), 20: frame(1100)])
    let retired = try #require(created[2])
    displays = [first]
    scheduler.update(frames: [10: frame(0), 20: frame(1100)])
    #expect(retired.stopped)
    created[1]?.fire()
    #expect(ticks == [[10, 20]])
    displays = [first, second]
    scheduler.update(frames: [20: frame(1100)])
    retired.fire()
    #expect(ticks.count == 1)
    created[2]?.fire()
    #expect(ticks == [[10, 20], [20]])
    scheduler.stop()
  }

  @Test("no-display fallback advances and releases its owner when idle")
  func fallbackLifetime() async throws {
    var ticks = 0
    var scheduler: AnimationDisplayLink? = AnimationDisplayLink(
      displays: { [] },
      tick: { ids, _ in
        #expect(ids == [10])
        ticks += 1
      }
    )
    weak let reference = scheduler
    scheduler?.update(frames: [10: frame(0)])
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while ticks == 0, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(1)) }
    try #require(ticks > 0)
    scheduler?.update(frames: [:])
    scheduler = nil
    #expect(reference == nil)
  }

  private func frame(_ x: Double) -> CGRect {
    CGRect(x: x, y: 0, width: 100, height: 100)
  }

  private func display(
    _ id: UInt32,
    x: Double,
    created: @escaping (TestScreenLink) -> Void
  ) -> AnimationDisplayLink.Display {
    AnimationDisplayLink.Display(id: id, frame: CGRect(x: x, y: 0, width: 1000, height: 800)) {
      tick in
      let link = TestScreenLink(tick: tick)
      created(link)
      return link
    }
  }
}

@MainActor
private final class TestScreenLink: AnimationScreenLink {
  private(set) var stopped = false
  private let tick: AnimationDisplayLink.Tick

  init(tick: @escaping AnimationDisplayLink.Tick) { self.tick = tick }

  func fire() { tick(.now) }
  func stop() { stopped = true }
}
