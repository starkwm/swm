import AppKit

private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

/// One serial execution lane per application, with a bounded per-window mailbox.
@MainActor
final class AnimationFrameDelivery {
  typealias Completion = @MainActor @Sendable (AnimationFrameCompletion) -> Void

  private var lanes = [pid_t: AnimationAppLane]()
  private let backend: (CGWindowID) -> AnimationFrameBackend?

  init(backend: @escaping (CGWindowID) -> AnimationFrameBackend?) {
    self.backend = backend
  }

  convenience init(windows: Windows) {
    self.init { id in
      guard let window = windows.window(by: id), let element = window.element,
        let application = window.application
      else { return nil }
      let handles = AnimationAXHandles(window: element, application: application.element)
      return handles.backend(processID: application.processID)
    }
  }

  /// Explicit synchronous commands must run after started AX calls and batch restoration.
  /// Workers never wait for main-actor completions, so this barrier cannot depend on its caller.
  func waitForPendingOperations(for windowID: CGWindowID) {
    guard let processID = backend(windowID)?.processID else { return }
    lanes[processID]?.waitForPendingOperations()
  }

  func submit(
    windowID: CGWindowID,
    generation: AnimationGeneration,
    sequence: UInt64,
    target: CGRect?,
    final: Bool,
    completion: @escaping Completion
  ) {
    guard let backend = backend(windowID) else {
      // Resolve vanished windows through the same completion path.
      let missing = AnimationFrameBackend(
        processID: 0,
        read: { nil },
        write: { _, _, _ in .moveFailed },
        beginBatch: { false },
        endBatch: { _ in }
      )
      completion(
        AnimationFrameCompletion(
          request: AnimationFrameRequest(
            windowID: windowID,
            generation: generation,
            sequence: sequence,
            target: target,
            final: final,
            backend: missing
          ),
          frame: nil,
          outcome: .failed
        )
      )
      return
    }
    let lane: AnimationAppLane
    if let existing = lanes[backend.processID] {
      lane = existing
    } else {
      lane = AnimationAppLane(processID: backend.processID)
      lanes[backend.processID] = lane
    }
    lane.submit(
      AnimationFrameRequest(
        windowID: windowID,
        generation: generation,
        sequence: sequence,
        target: target,
        final: final,
        backend: backend
      ),
      completion: completion
    )
    // Remove idle lanes without allowing two lanes for one app to overlap.
    lanes = lanes.filter { $0.key == backend.processID || !$0.value.isIdle }
  }
}

/// Immutable operations captured on the main actor, without sharing mutable Window models.
struct AnimationFrameBackend: Sendable {
  let processID: pid_t
  let read: @Sendable () -> CGRect?
  let write: @Sendable (CGRect, CGRect, AnimationGeneration) -> WindowFrameMutationResult
  let beginBatch: @Sendable () -> Bool
  let endBatch: @Sendable (Bool) -> Void
}

/// Cancellation does not wait for AX. Workers check before every subsequent AX write.
final class AnimationGeneration: @unchecked Sendable {
  var acceptedFrame: CGRect? {
    get { lock.withLock { accepted } }
    set { lock.withLock { accepted = valid ? newValue : nil } }
  }

  var isValid: Bool { lock.withLock { valid } }

  private let lock = NSLock()
  private var valid = true
  private var accepted: CGRect?

  func cancel() {
    lock.withLock {
      valid = false
      accepted = nil
    }
  }
}

struct AnimationFrameRequest: Sendable {
  let windowID: CGWindowID
  let generation: AnimationGeneration
  let sequence: UInt64
  /// Nil requests a fresh frame after previously started work has settled.
  let target: CGRect?
  let final: Bool
  let backend: AnimationFrameBackend
}

struct AnimationFrameCompletion: Sendable {
  enum Outcome: Sendable {
    case read
    case applied
    case verified
    case failed
  }

  let request: AnimationFrameRequest
  let frame: CGRect?
  let outcome: Outcome
}

private final class AnimationAppLane: @unchecked Sendable {
  private struct Pending: Sendable {
    let request: AnimationFrameRequest
    let completion: AnimationFrameDelivery.Completion
  }

  var isIdle: Bool { lock.withLock { !running } }

  private let queue: DispatchQueue
  private let lock = NSLock()
  private var pending = [CGWindowID: Pending]()
  private var running = false
  private var latest = [CGWindowID: (AnimationGeneration, UInt64)]()

  init(processID: pid_t) {
    queue = DispatchQueue(label: "swm.animation.ax.\(processID)", qos: .userInteractive)
  }

  func submit(
    _ request: AnimationFrameRequest,
    completion: @escaping AnimationFrameDelivery.Completion
  ) {
    let start = lock.withLock {
      pending[request.windowID] = Pending(request: request, completion: completion)
      latest[request.windowID] = (request.generation, request.sequence)
      if running { return false }
      running = true
      return true
    }
    if start { queue.async { self.drain() } }
  }

  func waitForPendingOperations() {
    queue.sync {}
  }

  private func drain() {
    while true {
      let batch = lock.withLock {
        let batch = pending.values.sorted { $0.request.windowID < $1.request.windowID }
        pending.removeAll(keepingCapacity: true)
        if batch.isEmpty {
          running = false
          latest.removeAll()
        }
        return batch
      }
      guard !batch.isEmpty else {
        return
      }
      let active = batch.filter { $0.request.generation.isValid }
      for (item, result) in executeBatch(active) {
        Task { @MainActor in
          guard item.request.generation.isValid else { return }
          item.completion(result)
        }
      }
    }
  }

  private func executeBatch(_ batch: [Pending]) -> [(Pending, AnimationFrameCompletion)] {
    guard let backend = batch.first?.request.backend else { return [] }
    let writes = batch.contains { $0.request.target != nil }
    let restore = writes ? backend.beginBatch() : false
    defer { if writes { backend.endBatch(restore) } }
    var results = [(Pending, AnimationFrameCompletion)]()
    for item in batch {
      let request = item.request
      guard request.generation.isValid,
        lock.withLock({
          latest[request.windowID]?.0 === request.generation
            && latest[request.windowID]?.1 == request.sequence
        })
      else { continue }
      results.append((item, execute(request)))
      lock.withLock {
        if latest[request.windowID]?.0 === request.generation,
          latest[request.windowID]?.1 == request.sequence
        {
          latest.removeValue(forKey: request.windowID)
        }
      }
    }
    return results
  }

  private func execute(_ request: AnimationFrameRequest) -> AnimationFrameCompletion {
    let backend = request.backend
    let diagnostics = AnimationDiagnostics.shared
    func read() -> CGRect? {
      diagnostics.measure("read", processID: backend.processID, backend.read)
    }
    func result(_ frame: CGRect?, _ outcome: AnimationFrameCompletion.Outcome)
      -> AnimationFrameCompletion
    {
      AnimationFrameCompletion(request: request, frame: frame, outcome: outcome)
    }
    let cached = request.generation.acceptedFrame
    guard let current = request.target == nil || request.final || cached == nil ? read() : cached
    else {
      request.generation.acceptedFrame = nil
      return result(nil, .failed)
    }
    guard let target = request.target else {
      request.generation.acceptedFrame = current
      return result(current, .read)
    }
    guard request.generation.isValid else { return result(nil, .failed) }
    if !request.final, current.matches(target, tolerance: 1) {
      return result(current, .applied)
    }
    let mutation = diagnostics.measure("mutation", processID: backend.processID) {
      backend.write(target, current, request.generation)
    }
    guard mutation == .success, request.generation.isValid else {
      request.generation.acceptedFrame = nil
      return result(nil, .failed)
    }
    if !request.final {
      request.generation.acceptedFrame = target
      return result(target, .applied)
    }
    request.generation.acceptedFrame = nil
    guard var actual = read() else { return result(nil, .failed) }
    if !actual.matches(target, tolerance: 1), request.generation.isValid {
      let correction = diagnostics.measure("mutation", processID: backend.processID) {
        backend.write(target, actual, request.generation)
      }
      guard correction == .success, let verified = read() else { return result(nil, .failed) }
      actual = verified
    }
    return result(actual, actual.matches(target, tolerance: 1) ? .verified : .failed)
  }
}

/// AX handles are immutable references; only a single app lane operates on these handles.
private final class AnimationAXHandles: @unchecked Sendable {
  private let window: AXUIElement
  private let application: AXUIElement

  init(window: AXUIElement, application: AXUIElement) {
    self.window = window
    self.application = application
  }

  func backend(processID: pid_t) -> AnimationFrameBackend {
    let client = AccessibilityClient.shared
    return AnimationFrameBackend(
      processID: processID,
      read: { client.frame(for: self.window) },
      write: { target, current, generation in
        WindowFrameMutation.apply(
          from: current,
          to: target,
          moveBeforeResizeWhenGrowing: true,
          resize: {
            generation.isValid && client.setSize($0, for: self.window, attribute: kAXSizeAttribute)
          },
          move: {
            generation.isValid
              && client.setPoint($0, for: self.window, attribute: kAXPositionAttribute)
          }
        )
      },
      beginBatch: {
        AnimationDiagnostics.shared.measure("enhanced-ui-begin", processID: processID) {
          let enabled = client.enhancedUIEnabled(
            for: self.application,
            attribute: kAXEnhancedUserInterface
          )
          if enabled {
            client.setAttributeValue(
              kCFBooleanFalse,
              for: self.application,
              attribute: kAXEnhancedUserInterface
            )
          }
          return enabled
        }
      },
      endBatch: { restore in
        AnimationDiagnostics.shared.measure("enhanced-ui-end", processID: processID) {
          if restore {
            client.setAttributeValue(
              kCFBooleanTrue,
              for: self.application,
              attribute: kAXEnhancedUserInterface
            )
          }
        }
      }
    )
  }
}
