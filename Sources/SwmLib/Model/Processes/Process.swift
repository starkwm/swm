import AppKit

private let processIgnoreList = [
  "Discord Helper (Plugin)",
  "Discord Helper (Renderer)",
  "Google Chrome Helper (Plugin)",
  "Google Chrome Helper (Renderer)",
  "Slack Helper (Plugin)",
  "Slack Helper (Renderer)",
]

/// Runtime model for an application process known to swm.
public final class Process: CustomStringConvertible {
  /// Debug description including process ID and name.
  public var description: String {
    "<Process pid: \(pid), name: \(name)>"
  }

  /// Carbon process serial number.
  var psn: ProcessSerialNumber

  /// Unix process identifier.
  var pid: pid_t

  /// Localized process name.
  var name: String

  /// Whether the process has terminated since being tracked.
  var terminated: Bool

  /// AppKit running-application model for the process when available.
  var application: NSRunningApplication?

  /// AppKit activation policy when known.
  var policy: NSApplication.ActivationPolicy?

  /// Create a process model from a Carbon process serial number.
  init?(psn: ProcessSerialNumber) {
    self.psn = psn

    var info = ProcessInfoRec()
    GetProcessInformation(&self.psn, &info)

    var pid = pid_t()
    GetProcessPID(&self.psn, &pid)

    self.pid = pid
    application = NSRunningApplication(processIdentifier: self.pid)
    name = application?.localizedName ?? "-"
    terminated = false

    if NSFileTypeForHFSTypeCode(info.processType).trimmingCharacters(
      in: CharacterSet(charactersIn: "'")
    ) == "XPC!" {
      return nil
    }

    if processIgnoreList.contains(where: { $0 == name }) {
      return nil
    }
  }

  /// Create a process model from explicit process fields.
  init(
    psn: ProcessSerialNumber,
    pid: pid_t,
    name: String,
    terminated: Bool = false,
    application: NSRunningApplication? = nil,
    policy: NSApplication.ActivationPolicy? = nil
  ) {
    self.psn = psn
    self.pid = pid
    self.name = name
    self.terminated = terminated
    self.application = application
    self.policy = policy
  }
}

extension Process: @unchecked Sendable {}
