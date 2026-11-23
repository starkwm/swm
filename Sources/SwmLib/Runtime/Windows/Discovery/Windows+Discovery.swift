import ApplicationServices
import CHIServices
import Foundation

extension Windows {
  public func discover(from processes: Processes, onRecovery: @escaping () -> Void) {
    for process in processes.all() {
      if !workspace.isFinishedLaunching(process) {
        guard workspace.observeUntilFinishedLaunching(process) else {
          if process.application == nil {
            retryDiscovery(
              for: process,
              resolveProcess: { processes.find(by: process.psn) },
              retry: { Events.shared.post(.application(.launched(process))) }
            )
          }
          continue
        }
      }
      discover(process, resolveProcess: { processes.find(by: process.psn) }, onRecovery: onRecovery)
    }
  }

  func discover(
    _ process: Process,
    resolveProcess: @escaping () -> Process?,
    onRecovery: @escaping () -> Void
  ) {
    guard !process.terminated else { return }
    let retry = { [weak self] in
      self?.retryDiscovery(for: process, resolveProcess: resolveProcess) { [weak self] in
        self?.discover(process, resolveProcess: resolveProcess, onRecovery: onRecovery)
        onRecovery()
      }
    }
    guard let application = manage(process, retryObservation: { retry() }) else { return }
    if reconcileWindows(for: application) {
      resetDiscoveryRetries(for: process)
    } else {
      retry()
    }
  }

  func retryDiscovery(
    for process: Process,
    resolveProcess: @escaping () -> Process?,
    retry: @escaping () -> Void
  ) {
    let identity = ObjectIdentifier(process)
    guard !process.terminated, discoveryRetries[identity] == nil else { return }

    let retries = discoveryRetryCounts[identity, default: 0]
    guard let delay = discoveryRetryPolicy.delay(afterRetries: retries) else {
      discoveryRetryCounts.removeValue(forKey: identity)
      log("giving up discovery after \(retries) retries \(process)", level: .warn)
      return
    }

    discoveryRetryCounts[identity] = retries + 1
    discoveryRetries[identity] = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(for: delay)
      } catch { return }
      guard let self else { return }
      discoveryRetries.removeValue(forKey: identity)
      guard !process.terminated, resolveProcess() === process else {
        discoveryRetryCounts.removeValue(forKey: identity)
        return
      }
      retry()
    }
  }

  func resetDiscoveryRetries(for process: Process) {
    discoveryRetryCounts.removeValue(forKey: ObjectIdentifier(process))
  }

  func cancelDiscoveryRetry(for process: Process) {
    resetDiscoveryRetries(for: process)
    discoveryRetries.removeValue(forKey: ObjectIdentifier(process))?.cancel()
  }

  func waitForDiscoveryRetries() async {
    while !discoveryRetries.isEmpty {
      for task in Array(discoveryRetries.values) { await task.value }
    }
  }

  func refreshWindows() {
    for processID in Array(unresolvedApplicationIDs) {
      guard let application = applicationsByPID[processID] else {
        unresolvedApplicationIDs.remove(processID)
        continue
      }

      refreshWindows(for: application)
    }
  }

  @discardableResult
  func refreshWindows(for application: Application) -> Bool {
    reconcileWindows(for: application)
  }

  private func reconcileWindows(for application: Application) -> Bool {
    let processID = application.processID
    let globalWindowIDs = application.windowIdentifiers()
    addWindows(for: application)
    guard let globalWindowIDs else {
      unresolvedApplicationIDs.insert(processID)
      return false
    }

    let liveWindowIDs = Set(globalWindowIDs)
    let ignoredWindowIDs = ignoredWindowIDsByPID[processID, default: []]
      .intersection(liveWindowIDs)
    ignoredWindowIDsByPID[processID] = ignoredWindowIDs.isEmpty ? nil : ignoredWindowIDs

    guard !unresolvedWindowIDs(in: globalWindowIDs, for: processID).isEmpty else {
      remoteWindowScans.removeValue(forKey: processID)
      unresolvedApplicationIDs.remove(processID)
      return true
    }

    unresolvedApplicationIDs.insert(processID)
    var scan = remoteWindowScans[processID] ?? RemoteWindowScan()
    scan.retainWindows(liveWindowIDs)
    let scannableWindowIDs = scan.scannableWindowIDs(
      unresolvedWindowIDs(in: globalWindowIDs, for: processID)
    )
    if !scannableWindowIDs.isEmpty {
      resolveRemoteWindows(scannableWindowIDs, scan: &scan, for: application)
      let remainingWindowIDs = unresolvedWindowIDs(in: globalWindowIDs, for: processID)
      scan.finishBatch(unresolved: remainingWindowIDs)
      if remainingWindowIDs.isEmpty {
        log("workaround resolved all windows \(application)", level: .info)
        unresolvedApplicationIDs.remove(processID)
      } else if scan.scannableWindowIDs(remainingWindowIDs).isEmpty {
        log("workaround stopped scanning unresolvable windows \(application)", level: .info)
      } else {
        log("workaround failed to resolve all windows \(application)", level: .info)
      }
      if scan.scannableWindowIDs(remainingWindowIDs).isEmpty { scan.restartCycle() }
    }
    remoteWindowScans[processID] = scan
    return true
  }

  private func unresolvedWindowIDs(
    in globalWindowIDs: [CGWindowID],
    for processID: pid_t
  ) -> [CGWindowID] {
    let ignoredWindowIDs = ignoredWindowIDsByPID[processID, default: []]
    return globalWindowIDs.filter { windowsByID[$0] == nil && !ignoredWindowIDs.contains($0) }
  }

  private func resolveRemoteWindows(
    _ windowIDs: [CGWindowID],
    scan: inout RemoteWindowScan,
    for application: Application
  ) {
    log(
      "application has windows that are not resolved, attempting workaround \(application)",
      level: .info
    )

    var unresolvedWindowIDs = Set(windowIDs)
    let tokenIDs = scan.nextBatch(for: windowIDs)

    log(
      "scanning remote window tokens \(tokenIDs.lowerBound)...\(tokenIDs.upperBound) for \(application)"
    )

    for id in tokenIDs {
      guard !unresolvedWindowIDs.isEmpty else { break }

      let token = createRemoteToken(for: application.processID, with: id)

      guard
        let element = _AXUIElementCreateWithRemoteToken(token),
        AccessibilityClient.shared.isWindow(element),
        let windowID = AccessibilityClient.shared.optionalWindowID(for: element),
        unresolvedWindowIDs.contains(windowID)
      else {
        continue
      }

      guard addWindow(for: application, with: element, id: windowID) != nil else {
        if ignoredWindowIDsByPID[application.processID]?.contains(windowID) == true {
          unresolvedWindowIDs.remove(windowID)
        }
        continue
      }

      unresolvedWindowIDs.remove(windowID)
      log("resolved window \(windowID) for \(application)")
    }
  }

  private func createRemoteToken(for pid: pid_t, with id: Int) -> CFData {
    var token = Data()

    token.append(contentsOf: withUnsafeBytes(of: pid) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0x636f_636f)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: id) { Data($0) })

    return token as CFData
  }
}
