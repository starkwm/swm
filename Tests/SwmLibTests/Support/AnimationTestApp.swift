import AppKit

@testable import SwmLib

final class AnimationTestApp: @unchecked Sendable {
  private static let initialFrame = CGRect(x: 0, y: 0, width: 100, height: 100)

  let processID: pid_t
  var frame: CGRect {
    get { frame(for: 1) }
    set { setFrame(newValue, for: 1) }
  }
  var clampWrites: Bool {
    get { lock.withLock { clamp } }
    set { lock.withLock { clamp = newValue } }
  }
  var readCount: Int { lock.withLock { reads } }
  var writeCount: Int { lock.withLock { writes } }
  var beginCount: Int { lock.withLock { begins } }
  var endCount: Int { lock.withLock { ends } }
  var backend: AnimationFrameBackend { backend(for: 1) }

  private let lock = NSLock()
  private let gate = DispatchSemaphore(value: 0)
  private let settlementDelay: Double
  private var frames = [CGWindowID: CGRect]()
  private var pendingFrames = [CGWindowID: (CGRect, ContinuousClock.Instant)]()
  private var ignoredWrites: Int
  private var reads = 0
  private var writes = 0
  private var begins = 0
  private var ends = 0
  private var shouldBlock = false
  private var clamp = false

  init(
    processID: pid_t,
    settlementDelay: Double = 0,
    ignoredWrites: Int = 0
  ) {
    self.processID = processID
    self.settlementDelay = settlementDelay
    self.ignoredWrites = ignoredWrites
  }

  func backend(for windowID: CGWindowID) -> AnimationFrameBackend {
    AnimationFrameBackend(
      processID: processID,
      read: {
        return self.lock.withLock {
          self.reads += 1
          return self.settledFrame(for: windowID)
        }
      },
      write: { target, _, generation in
        guard generation.isValid else { return .moveFailed }
        let block = self.lock.withLock {
          self.writes += 1
          let block = self.shouldBlock
          self.shouldBlock = false
          return block
        }
        if block { _ = self.gate.wait(timeout: .now() + 3) }
        self.lock.withLock {
          if self.ignoredWrites > 0 {
            self.ignoredWrites -= 1
          } else if !self.clamp {
            if self.settlementDelay > 0 {
              self.pendingFrames[windowID] = (
                target, .now.advanced(by: .seconds(self.settlementDelay))
              )
            } else {
              self.frames[windowID] = target
            }
          }
        }
        return .success
      },
      beginBatch: {
        self.lock.withLock { self.begins += 1 }
        return true
      },
      endBatch: { _ in self.lock.withLock { self.ends += 1 } }
    )
  }

  func frame(for windowID: CGWindowID) -> CGRect {
    lock.withLock { settledFrame(for: windowID) }
  }

  func setFrame(_ frame: CGRect, for windowID: CGWindowID) {
    lock.withLock {
      pendingFrames.removeValue(forKey: windowID)
      frames[windowID] = frame
    }
  }

  func blockNextWrite() { lock.withLock { shouldBlock = true } }
  func release() { gate.signal() }

  private func settledFrame(for windowID: CGWindowID) -> CGRect {
    if let (frame, deadline) = pendingFrames[windowID], ContinuousClock.now >= deadline {
      frames[windowID] = frame
      pendingFrames.removeValue(forKey: windowID)
    }
    return frames[windowID] ?? Self.initialFrame
  }
}
