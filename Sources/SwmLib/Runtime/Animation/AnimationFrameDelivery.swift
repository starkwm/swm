import AppKit

private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

/// One serial execution lane per application, with a bounded per-window mailbox.
@MainActor
final class AnimationFrameDelivery {
  typealias Completion = @MainActor @Sendable (AnimationFrameCompletion) -> Void

  private var lanes = [pid_t: AnimationAppLane]()
  private let settlementDelay: TimeInterval
  private let backend: (CGWindowID) -> AnimationFrameBackend?

  init(
    settlementDelay: TimeInterval = 0.1,
    backend: @escaping (CGWindowID) -> AnimationFrameBackend?
  ) {
    self.settlementDelay = settlementDelay
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
      lane = AnimationAppLane(processID: backend.processID, settlementDelay: settlementDelay)
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
    enum Phase: Sendable {
      case write
      case verify
      case verifyCorrection
    }

    let request: AnimationFrameRequest
    let completion: AnimationFrameDelivery.Completion
    var phase = Phase.write
  }

  private struct Settlement {
    let token: UUID
    let work: DispatchWorkItem
  }

  var isIdle: Bool { lock.withLock { !running && settlements.isEmpty } }

  private let queue: DispatchQueue
  private let lock = NSLock()
  private let settlementDelay: TimeInterval
  private var pending = [CGWindowID: Pending]()
  private var settlements = [CGWindowID: Settlement]()
  private var running = false
  private var latest = [CGWindowID: (AnimationGeneration, UInt64)]()

  init(processID: pid_t, settlementDelay: TimeInterval) {
    self.settlementDelay = settlementDelay
    queue = DispatchQueue(label: "swm.animation.ax.\(processID)", qos: .userInteractive)
  }

  func submit(
    _ request: AnimationFrameRequest,
    completion: @escaping AnimationFrameDelivery.Completion
  ) {
    let start = lock.withLock {
      settlements.removeValue(forKey: request.windowID)?.work.cancel()
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
          latest = latest.filter { settlements[$0.key] != nil }
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
    let writes = batch.contains { $0.request.target != nil && $0.phase != .verifyCorrection }
    let restore = writes ? backend.beginBatch() : false
    defer { if writes { backend.endBatch(restore) } }
    var results = [(Pending, AnimationFrameCompletion)]()
    for item in batch {
      let request = item.request
      guard isCurrent(request), let result = execute(item) else { continue }
      results.append((item, result))
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

  private func isCurrent(_ request: AnimationFrameRequest) -> Bool {
    request.generation.isValid
      && lock.withLock {
        latest[request.windowID]?.0 === request.generation
          && latest[request.windowID]?.1 == request.sequence
      }
  }

  /// Schedule readback without holding the app's AX lane or its enhanced-UI workaround open.
  private func settle(_ item: Pending, phase: Pending.Phase) {
    let token = UUID()
    var verification = item
    verification.phase = phase
    let next = verification
    let work = DispatchWorkItem { [weak self] in
      guard let self else { return }
      let start = self.lock.withLock {
        guard self.settlements[next.request.windowID]?.token == token else { return false }
        self.settlements.removeValue(forKey: next.request.windowID)
        guard next.request.generation.isValid,
          self.latest[next.request.windowID]?.0 === next.request.generation,
          self.latest[next.request.windowID]?.1 == next.request.sequence
        else {
          self.latest.removeValue(forKey: next.request.windowID)
          return false
        }
        self.pending[next.request.windowID] = next
        if self.running { return false }
        self.running = true
        return true
      }
      if start { self.drain() }
    }
    let scheduled = lock.withLock {
      guard item.request.generation.isValid,
        latest[item.request.windowID]?.0 === item.request.generation,
        latest[item.request.windowID]?.1 == item.request.sequence
      else { return false }
      settlements[item.request.windowID] = Settlement(token: token, work: work)
      return true
    }
    if scheduled { queue.asyncAfter(deadline: .now() + settlementDelay, execute: work) }
  }

  private func execute(_ item: Pending) -> AnimationFrameCompletion? {
    let request = item.request
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
    if item.phase != .write {
      guard let target = request.target, let actual = read(), isCurrent(request) else {
        return result(nil, .failed)
      }
      if actual.matches(target, tolerance: 1) { return result(actual, .verified) }
      guard item.phase == .verify else { return result(actual, .failed) }
      let correction = diagnostics.measure("mutation", processID: backend.processID) {
        backend.write(target, actual, request.generation)
      }
      guard correction == .success, isCurrent(request) else { return result(nil, .failed) }
      settle(item, phase: .verifyCorrection)
      return nil
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
    guard isCurrent(request) else { return result(nil, .failed) }
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
    settle(item, phase: .verify)
    return nil
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
