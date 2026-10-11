import AppKit
import Testing

@testable import SwmLib

@MainActor
@Suite("AnimationDisplayLink")
struct AnimationDisplayLinkTests {
  @Test("presentationTime: bounds stale and invalid timestamps")
  func presentationTimeBoundsStaleAndInvalidTimestamps() {
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

  @Test("deinit: releases watchdog and stops links")
  func deinitReleasesWatchdogAndStopsLinks() {
    var link: TestScreenLink?
    var scheduler: AnimationDisplayLink? = AnimationDisplayLink(
      displays: { [display(1, x: 0, created: { link = $0 })] },
      tick: { _, _ in }
    )
    weak let reference = scheduler
    scheduler?.update(frames: [10: frame(0)])
    scheduler = nil
    #expect(reference == nil)
    #expect(link?.stopped == true)
  }

  @Test("update: advances windows on their display and stops idle links")
  func updateAdvancesWindowsOnTheirDisplayAndStopsIdleLinks() {
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

  @Test("update: migrates disconnected displays and rejects retired callbacks")
  func updateMigratesDisconnectedDisplaysAndRejectsRetiredCallbacks() throws {
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

  @Test("update: schedules a fallback without retaining its owner")
  func updateSchedulesAFallbackWithoutRetainingItsOwner() async throws {
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

  @Test("update: recovers a silent display automatically")
  func updateRecoversASilentDisplayAutomatically() async throws {
    var link: TestScreenLink?
    var recovered = [Set<CGWindowID>]()
    let scheduler = AnimationDisplayLink(
      displays: { [display(1, x: 0, created: { link = $0 })] },
      stalled: { ids, _ in recovered.append(ids) },
      tick: { _, _ in Issue.record("silent display ticked") }
    )
    defer { scheduler.stop() }
    scheduler.update(frames: [10: frame(0)])
    let deadline = ContinuousClock.now.advanced(by: .seconds(4))
    while recovered.isEmpty, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(recovered == [[10]])
    #expect(link?.stopped == true)
  }

  @Test("checkForStalledLinks: retires silent displays and rejects late callbacks")
  func checkForStalledLinksRetiresSilentDisplaysAndRejectsLateCallbacks() throws {
    var created = [UInt32: TestScreenLink]()
    let displays = [
      display(1, x: 0, created: { created[1] = $0 }),
      display(2, x: 1000, created: { created[2] = $0 }),
    ]
    var stalled = [Set<CGWindowID>]()
    var ticks = [Set<CGWindowID>]()
    let scheduler = AnimationDisplayLink(
      displays: { displays },
      stalled: { ids, _ in stalled.append(ids) },
      tick: { ids, _ in ticks.append(ids) }
    )
    scheduler.update(frames: [10: frame(0), 20: frame(1100)])
    let silent = try #require(created[1])
    let healthy = try #require(created[2])
    let now = ContinuousClock.now
    scheduler.checkForStalledLinks(at: now.advanced(by: .seconds(1)))
    #expect(stalled.isEmpty)
    healthy.fire(at: now.advanced(by: .seconds(2)))
    scheduler.checkForStalledLinks(at: now.advanced(by: .seconds(3)))
    #expect(stalled == [[10]])
    #expect(silent.stopped)
    #expect(!healthy.stopped)
    silent.fire()
    #expect(ticks == [[20]])
    // A later pass makes a new link. A callback from the retired session cannot tick it.
    scheduler.update(frames: [10: frame(0), 20: frame(1100)])
    silent.fire()
    created[1]?.fire()
    #expect(ticks == [[20], [10]])
    scheduler.stop()
    scheduler.checkForStalledLinks(at: now.advanced(by: .seconds(10)))
    #expect(stalled == [[10]])
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

  func fire(at time: ContinuousClock.Instant = .now) { tick(time) }
  func stop() { stopped = true }
}
