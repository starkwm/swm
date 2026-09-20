import AppKit
import QuartzCore

/// Delivers coalesced main-run-loop ticks without queuing work from a rendering thread.
@MainActor
final class AnimationDisplayLink: NSObject {
  private var link: CADisplayLink?
  private let tick: () -> Void

  init(tick: @escaping () -> Void) {
    self.tick = tick
  }

  isolated deinit {
    link?.invalidate()
  }

  /// Use the main display's cadence, capped to avoid increasing Accessibility traffic.
  func start() -> Bool {
    guard let screen = NSScreen.main else { return false }
    let link = screen.displayLink(target: self, selector: #selector(advance))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    self.link = link
    link.add(to: .main, forMode: .common)
    return true
  }

  func stop() {
    link?.invalidate()
    link = nil
  }

  @objc private func advance(_ link: CADisplayLink) {
    tick()
  }
}
