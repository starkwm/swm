import AppKit

private let processIgnoreList = [
  "Discord Helper (Plugin)",
  "Discord Helper (Renderer)",
  "Google Chrome Helper (Plugin)",
  "Google Chrome Helper (Renderer)",
  "Slack Helper (Plugin)",
  "Slack Helper (Renderer)",
]

public final class Process: CustomStringConvertible {
  public var description: String {
    "<Process pid: \(pid), name: \(name)>"
  }

  public var psn: ProcessSerialNumber
  public var pid: pid_t
  public var name: String
  public var terminated: Bool
  public var application: NSRunningApplication?
  public var policy: NSApplication.ActivationPolicy?

  public init?(psn: ProcessSerialNumber) {
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
      log("ignoring xpc service \(name)")
      return nil
    }

    if processIgnoreList.contains(where: { $0 == name }) {
      return nil
    }
  }

  public init(
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

  deinit {
    log("process deinit \(self)")
  }
}
