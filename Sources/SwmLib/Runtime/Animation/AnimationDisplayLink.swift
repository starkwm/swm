import AppKit
import QuartzCore

/// One capped display link per active display, with a bounded no-display fallback.
@MainActor
final class AnimationDisplayLink {
  typealias Tick = (ContinuousClock.Instant) -> Void

  struct Display {
    let id: UInt32
    let frame: CGRect
    let makeLink: (@escaping Tick) -> any AnimationScreenLink
  }

  private struct Session {
    let token: UUID
    let link: any AnimationScreenLink
  }

  /// Convert the presentation timestamp's Core Animation clock into ContinuousClock time.
  static func presentationTime(
    targetTimestamp: CFTimeInterval,
    mediaTime: CFTimeInterval,
    now: ContinuousClock.Instant
  ) -> ContinuousClock.Instant {
    // A stale or discontinuous timestamp must not jump an animation far into the future.
    let delta = targetTimestamp - mediaTime
    return now.advanced(by: .seconds(delta.isFinite ? min(1.0 / 30, max(0, delta)) : 0))
  }

  private static func currentDisplays() -> [Display] {
    NSScreen.screens.compactMap { screen in
      guard let id = screen.id else { return nil }
      return Display(id: id, frame: screen.axVisibleFrame) { tick in
        ScreenAnimationLink(screen: screen, tick: tick)
      }
    }
  }

  private var links = [UInt32: Session]()
  private let displays: () -> [Display]
  private var windowsByDisplay = [UInt32: Set<CGWindowID>]()
  private var fallback: Task<Void, Never>?
  private var fallbackIDs = Set<CGWindowID>()
  private let tick: (Set<CGWindowID>, ContinuousClock.Instant) -> Void

  init(
    displays: (() -> [Display])? = nil,
    tick: @escaping (Set<CGWindowID>, ContinuousClock.Instant) -> Void
  ) {
    self.displays = displays ?? Self.currentDisplays
    self.tick = tick
  }

  isolated deinit { stop() }

  func update(frames: [CGWindowID: CGRect]) {
    let displays = displays()
    var groups = [UInt32: Set<CGWindowID>]()
    var missing = Set<CGWindowID>()
    for (id, frame) in frames {
      if let display = displays.max(by: {
        frame.intersection($0.frame).area < frame.intersection($1.frame).area
      }) {
        groups[display.id, default: []].insert(id)
      } else {
        missing.insert(id)
      }
    }
    windowsByDisplay = groups
    for id in Array(links.keys) where groups[id] == nil {
      links.removeValue(forKey: id)?.link.stop()
    }
    for display in displays {
      let id = display.id
      guard groups[id] != nil, links[id] == nil else { continue }
      let token = UUID()
      let link = display.makeLink { [weak self] time in
        guard let self, self.links[id]?.token == token,
          let ids = self.windowsByDisplay[id]
        else { return }
        self.tick(ids, time)
      }
      links[id] = Session(token: token, link: link)
    }
    fallbackIDs = missing
    if missing.isEmpty {
      fallback?.cancel()
      fallback = nil
    } else if fallback == nil {
      fallback = Task { [weak self] in
        let clock = ContinuousClock()
        var deadline = clock.now
        while !Task.isCancelled {
          deadline = WindowFrameReconciler.nextAnimationDeadline(after: deadline, now: clock.now)
          do { try await clock.sleep(until: deadline, tolerance: .zero) } catch { return }
          guard let self, !Task.isCancelled else { return }
          AnimationDiagnostics.shared.record(
            "fallback-deadline",
            since: clock.now,
            missedDeadline: deadline.duration(to: clock.now) > .seconds(1.0 / 60)
          )
          self.tick(self.fallbackIDs, clock.now)
        }
      }
    }
  }

  func stop() {
    for session in links.values { session.link.stop() }
    links.removeAll()
    windowsByDisplay.removeAll()
    fallbackIDs.removeAll()
    fallback?.cancel()
    fallback = nil
  }
}

@MainActor
protocol AnimationScreenLink: AnyObject {
  func stop()
}

@MainActor
private final class ScreenAnimationLink: NSObject, AnimationScreenLink {
  private var link: CADisplayLink?
  private var previousTimestamp: CFTimeInterval?
  private let tick: (ContinuousClock.Instant) -> Void

  init(screen: NSScreen, tick: @escaping (ContinuousClock.Instant) -> Void) {
    self.tick = tick
    super.init()
    let link = screen.displayLink(target: self, selector: #selector(advance))
    // Keep the AX traffic cap until live throughput supports a higher rate.
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    self.link = link
    link.add(to: .main, forMode: .common)
  }

  func stop() {
    link?.invalidate()
    link = nil
  }

  @objc private func advance(_ link: CADisplayLink) {
    let now = ContinuousClock.now
    let interval = max(1.0 / 60, link.targetTimestamp - link.timestamp)
    if let previousTimestamp {
      AnimationDiagnostics.shared.record(
        "display-deadline",
        since: now,
        missedDeadline: link.timestamp - previousTimestamp > interval * 1.5
      )
    }
    previousTimestamp = link.timestamp
    tick(
      AnimationDisplayLink.presentationTime(
        targetTimestamp: link.targetTimestamp,
        mediaTime: CACurrentMediaTime(),
        now: now
      )
    )
  }
}
