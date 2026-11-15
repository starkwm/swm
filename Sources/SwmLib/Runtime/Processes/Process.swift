import AppKit
import CHIServices

private let processIgnoreList = [
  "Discord Helper (Plugin)",
  "Discord Helper (Renderer)",
  "Google Chrome Helper (Plugin)",
  "Google Chrome Helper (Renderer)",
  "Slack Helper (Plugin)",
  "Slack Helper (Renderer)",
]

@MainActor
public final class Process: @MainActor CustomStringConvertible {
  public var description: String {
    "<Process pid: \(pid), name: \(name)>"
  }

  var psn: ProcessSerialNumber

  var pid: pid_t

  var name: String

  var terminated: Bool

  var application: NSRunningApplication?

  var policy: NSApplication.ActivationPolicy?

  init?(psn: ProcessSerialNumber) {
    self.psn = psn

    var info = ProcessInfoRec()
    SWMGetProcessInformation(&self.psn, &info)

    var pid = pid_t()
    SWMGetProcessPID(&self.psn, &pid)

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

  func resolveApplication(
    lookup: (pid_t) -> NSRunningApplication? = { NSRunningApplication(processIdentifier: $0) }
  ) -> NSRunningApplication? {
    if let application { return application }
    guard !terminated, let found = lookup(pid) else { return nil }

    application = found
    if name == "-", let localizedName = found.localizedName { name = localizedName }
    return found
  }

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
