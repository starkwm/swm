import Carbon

/// Forward Carbon process events to a process manager instance.
private func processEventHandler(
  _: EventHandlerCallRef?,
  event: EventRef?,
  context: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let event = event else { return noErr }
  guard let context else { return noErr }

  let processManager = Unmanaged<ProcessManager>.fromOpaque(context).takeUnretainedValue()
  return processManager.handle(event: event)
}

/// Tracks running application processes and publishes process lifecycle events.
public final class ProcessManager {
  private var processes = [UInt32: Process]()

  /// Create an empty process manager.
  public init() {}

  /// Seed the process list and start observing Carbon application events.
  public func start() -> Result<Void, ProcessManagerError> {
    addRunningProcesses()

    let eventTypes = [
      EventTypeSpec(
        eventClass: OSType(kEventClassApplication),
        eventKind: OSType(kEventAppLaunched)
      ),
      EventTypeSpec(
        eventClass: OSType(kEventClassApplication),
        eventKind: OSType(kEventAppTerminated)
      ),
      EventTypeSpec(
        eventClass: OSType(kEventClassApplication),
        eventKind: OSType(kEventAppFrontSwitched)
      ),
    ]

    let result = InstallEventHandler(
      GetApplicationEventTarget(),
      processEventHandler,
      eventTypes.count,
      eventTypes,
      Unmanaged.passUnretained(self).toOpaque(),
      nil
    )

    return result == noErr
      ? .success(()) : .failure(.accessFailed("failed to install event handler"))
  }

  /// Return all currently tracked processes.
  public func all() -> [Process] {
    Array(processes.values)
  }

  /// Find a tracked process by process serial number.
  func find(by psn: ProcessSerialNumber) -> Process? {
    processes[psn.lowLongOfPSN]
  }

  /// Handle a Carbon application event.
  func handle(event: EventRef) -> OSStatus {
    var psn = ProcessSerialNumber()

    GetEventParameter(
      event,
      UInt32(kEventParamProcessID),
      UInt32(typeProcessSerialNumber),
      nil,
      MemoryLayout<ProcessSerialNumber>.size,
      nil,
      &psn
    )

    switch Int(GetEventKind(event)) {
    case kEventAppLaunched:
      applicationLaunched(with: psn)

    case kEventAppTerminated:
      applicationTerminated(with: psn)

    case kEventAppFrontSwitched:
      applicationFrontSwitched(to: psn)

    default:
      break
    }

    return noErr
  }

  /// Add all currently running processes to the tracked process map.
  private func addRunningProcesses() {
    var psn = ProcessSerialNumber()

    while GetNextProcess(&psn) == noErr {
      guard let process = Process(psn: psn) else { continue }
      processes[process.psn.lowLongOfPSN] = process
    }
  }

  /// Track a newly launched process and publish an application launch event.
  private func applicationLaunched(with psn: ProcessSerialNumber) {
    guard processes[psn.lowLongOfPSN] == nil else { return }
    guard let process = Process(psn: psn) else { return }

    processes[process.psn.lowLongOfPSN] = process

    EventManager.shared.post(.application(.launched(process)))
  }

  /// Mark a tracked process as terminated and publish an application termination event.
  private func applicationTerminated(with psn: ProcessSerialNumber) {
    guard let process = processes[psn.lowLongOfPSN] else { return }

    processes.removeValue(forKey: psn.lowLongOfPSN)
    process.terminated = true

    EventManager.shared.post(.application(.terminated(process)))
  }

  /// Publish a frontmost-application change event for a tracked process.
  private func applicationFrontSwitched(to psn: ProcessSerialNumber) {
    guard let process = processes[psn.lowLongOfPSN] else { return }

    EventManager.shared.post(.application(.frontSwitched(process)))
  }
}

extension ProcessManager: @unchecked Sendable {}

/// Errors raised while starting or accessing process observation.
public enum ProcessManagerError: Error, CustomStringConvertible {
  /// Process observation could not be started or accessed.
  case accessFailed(String)

  /// Human-readable process manager failure description.
  public var description: String {
    switch self {
    case .accessFailed(let message):
      return message
    }
  }
}
