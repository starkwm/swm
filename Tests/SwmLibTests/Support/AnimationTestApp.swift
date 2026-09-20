import AppKit

@testable import SwmLib

final class AnimationTestApp: @unchecked Sendable {
  private static let initialFrame = CGRect(x: 0, y: 0, width: 100, height: 100)

  let processID: pid_t
  let readDelay: Double
  let writeDelay: Double
  var frame: CGRect {
    get { frame(for: 1) }
    set { lock.withLock { frames[1] = newValue } }
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
  private var frames = [CGWindowID: CGRect]()
  private var reads = 0
  private var writes = 0
  private var begins = 0
  private var ends = 0
  private var shouldBlock = false
  private var clamp = false

  init(processID: pid_t, readDelay: Double = 0, writeDelay: Double = 0) {
    self.processID = processID
    self.readDelay = readDelay
    self.writeDelay = writeDelay
  }

  func backend(for windowID: CGWindowID) -> AnimationFrameBackend {
    AnimationFrameBackend(
      processID: processID,
      read: {
        if self.readDelay > 0 { Thread.sleep(forTimeInterval: self.readDelay) }
        return self.lock.withLock {
          self.reads += 1
          return self.frames[windowID] ?? Self.initialFrame
        }
      },
      write: { target, _, generation in
        guard generation.isValid else { return .moveFailed }
        if self.writeDelay > 0 { Thread.sleep(forTimeInterval: self.writeDelay) }
        let block = self.lock.withLock {
          self.writes += 1
          let block = self.shouldBlock
          self.shouldBlock = false
          return block
        }
        if block { _ = self.gate.wait(timeout: .now() + 3) }
        self.lock.withLock {
          if !self.clamp { self.frames[windowID] = target }
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
    lock.withLock { frames[windowID] ?? Self.initialFrame }
  }

  func blockNextWrite() { lock.withLock { shouldBlock = true } }
  func release() { gate.signal() }
}
