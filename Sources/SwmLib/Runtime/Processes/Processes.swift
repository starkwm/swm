import CHIServices
import Carbon

private func processEventHandler(
  _: EventHandlerCallRef?,
  event: EventRef?,
  context: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let event = event else { return noErr }
  guard let context else { return noErr }

  let processes = Unmanaged<Processes>.fromOpaque(context).takeUnretainedValue()
  return processes.handle(event: event)
}

@MainActor
public final class Processes {
  private var processes = [UInt32: Process]()

  public init() {}

  init(tracking processes: [Process]) {
    for process in processes {
      self.processes[process.psn.lowLongOfPSN] = process
    }
  }

  public func observe() -> Result<Void, ProcessesError> {
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

  public func all() -> [Process] {
    Array(processes.values)
  }

  func find(by psn: ProcessSerialNumber) -> Process? {
    processes[psn.lowLongOfPSN]
  }

  nonisolated func handle(event: EventRef) -> OSStatus {
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

    let eventKind = Int(GetEventKind(event))
    DispatchQueue.main.async { [self] in
      handle(eventKind: eventKind, psn: psn)
    }

    return noErr
  }

  private func handle(eventKind: Int, psn: ProcessSerialNumber) {
    switch eventKind {
    case kEventAppLaunched:
      applicationLaunched(with: psn)

    case kEventAppTerminated:
      applicationTerminated(with: psn)

    case kEventAppFrontSwitched:
      applicationFrontSwitched(to: psn)

    default:
      break
    }
  }

  private func addRunningProcesses() {
    var psn = ProcessSerialNumber()

    while SWMGetNextProcess(&psn) == noErr {
      guard let process = Process(psn: psn) else { continue }
      processes[process.psn.lowLongOfPSN] = process
    }
  }

  private func applicationLaunched(with psn: ProcessSerialNumber) {
    guard processes[psn.lowLongOfPSN] == nil else { return }
    guard let process = Process(psn: psn) else { return }

    processes[process.psn.lowLongOfPSN] = process

    Events.shared.post(.application(.launched(process)))
  }

  private func applicationTerminated(with psn: ProcessSerialNumber) {
    guard let process = processes[psn.lowLongOfPSN] else { return }

    processes.removeValue(forKey: psn.lowLongOfPSN)
    process.terminated = true

    Events.shared.post(.application(.terminated(process)))
  }

  private func applicationFrontSwitched(to psn: ProcessSerialNumber) {
    guard let process = processes[psn.lowLongOfPSN] else { return }

    Events.shared.post(.application(.frontSwitched(process)))
  }
}

public enum ProcessesError: Error, CustomStringConvertible {
  case accessFailed(String)

  public var description: String {
    switch self {
    case .accessFailed(let message):
      return message
    }
  }
}
