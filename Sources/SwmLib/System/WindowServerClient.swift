import AppKit
import Carbon
import CoreGraphics

/// Thin wrapper around private WindowServer APIs used by swm.
final class WindowServerClient {
  /// Shared WindowServer client.
  static let shared = WindowServerClient()

  private let screenIDKey = "Display Identifier"
  private let spaceIDKey = "ManagedSpaceID"
  private let spacesKey = "Spaces"

  /// Return the main WindowServer connection ID for this process.
  func mainConnectionID() -> Int32 {
    SLSMainConnectionID()
  }

  /// Return the process ID for the current frontmost process.
  func frontmostProcessID() -> pid_t? {
    var psn = ProcessSerialNumber()
    guard _SLPSGetFrontProcess(&psn) == noErr else { return nil }

    var pid = pid_t()
    guard GetProcessPID(&psn, &pid) == noErr else { return nil }

    return pid
  }

  /// Return the WindowServer connection ID for a process serial number.
  func connectionID(for psn: ProcessSerialNumber) -> Int32? {
    var psn = psn
    var connectionID: Int32 = -1

    guard SLSGetConnectionIDForPSN(mainConnectionID(), &psn, &connectionID) == .success else {
      return nil
    }

    return connectionID
  }

  /// Return the active WindowServer space ID.
  func activeSpace() -> UInt64 {
    SLSGetActiveSpace(mainConnectionID())
  }

  /// Return the current space ID for a display UUID.
  func currentSpace(for screenUUID: String) -> UInt64 {
    SLSManagedDisplayGetCurrentSpace(mainConnectionID(), screenUUID as CFString)
  }

  /// Return all known WindowServer space IDs.
  func allSpaceIDs() -> [UInt64] {
    managedDisplaySpaces().flatMap { info -> [UInt64] in
      guard let spacesInfo = info[spacesKey] as? [[String: AnyObject]] else { return [] }
      return spacesInfo.compactMap { managedSpaceID(from: $0[spaceIDKey]) }
    }
  }

  /// Return each display and the spaces assigned to it.
  func displaySpaces() -> [WindowServerDisplaySpaces] {
    managedDisplaySpaces().compactMap { info in
      guard let screenID = info[screenIDKey] as? String else { return nil }
      let spaces =
        (info[spacesKey] as? [[String: AnyObject]])?.compactMap {
          managedSpaceID(from: $0[spaceIDKey])
        } ?? []

      return WindowServerDisplaySpaces(id: screenID, spaces: spaces)
    }
  }

  /// Return the display UUID for a space ID.
  func screenID(for spaceID: UInt64) -> String? {
    for info in managedDisplaySpaces() {
      guard let screenID = info[screenIDKey] as? String,
        let spacesInfo = info[spacesKey] as? [[String: AnyObject]]
      else {
        continue
      }

      if spacesInfo.contains(where: { managedSpaceID(from: $0[spaceIDKey]) == spaceID }) {
        return screenID
      }
    }

    return nil
  }

  /// Return the space IDs containing a window.
  func spaceIDs(containing windowID: CGWindowID) -> [UInt64] {
    let identifiers =
      SLSCopySpacesForWindows(mainConnectionID(), 0x7, [windowID] as CFArray) as NSArray
    return identifiers.compactMap { managedSpaceID(from: $0) }
  }

  /// Return the WindowServer type for a space.
  func spaceType(for spaceID: UInt64) -> SpaceType {
    SpaceType(rawValue: SLSSpaceGetType(mainConnectionID(), spaceID)) ?? .unknown
  }

  /// Return valid top-level window IDs owned by an application connection on spaces.
  func windowIdentifiers(
    applicationConnectionID: Int32,
    spaceIDs: [UInt64]
  ) -> [CGWindowID] {
    let spaces = spaceIDs as CFArray
    let options: UInt32 = 0x7
    var setTags: UInt64 = 0
    var clearTags: UInt64 = 0

    let windows = SLSCopyWindowsWithOptionsAndTags(
      mainConnectionID(),
      UInt32(applicationConnectionID),
      spaces,
      options,
      &setTags,
      &clearTags
    )

    let query = SLSWindowQueryWindows(mainConnectionID(), windows, Int32(CFArrayGetCount(windows)))
    let iterator = SLSWindowQueryResultCopyWindows(query)

    var windowIDs = [CGWindowID]()

    while SLSWindowIteratorAdvance(iterator) {
      guard SLSWindowIteratorGetParentID(iterator) == 0 else { continue }

      let level = NSWindow.Level(rawValue: SLSWindowIteratorGetLevel(iterator))
      guard level == .normal || level == .floating || level == .modalPanel else { continue }

      let attributes = SLSWindowIteratorGetAttributes(iterator)
      let tags = SLSWindowIteratorGetTags(iterator)
      guard validWindow(attributes: attributes, tags: tags) else { continue }

      let id = SLSWindowIteratorGetWindowID(iterator)
      windowIDs.append(id)
    }

    return windowIDs
  }

  /// Return raw managed display-space dictionaries from WindowServer.
  private func managedDisplaySpaces() -> [[String: AnyObject]] {
    let info = SLSCopyManagedDisplaySpaces(mainConnectionID()) as NSArray
    return info.compactMap { $0 as? [String: AnyObject] }
  }

  /// Normalize a managed space ID value from WindowServer dictionaries.
  private func managedSpaceID(from value: Any?) -> UInt64? {
    if let id = value as? UInt64 {
      return id
    }

    return (value as? NSNumber)?.uint64Value
  }

  /// Return whether WindowServer attributes and tags describe a manageable window.
  private func validWindow(attributes: UInt64, tags: UInt64) -> Bool {
    if ((attributes & 0x2) != 0 || (tags & 0x400_0000_0000_0000) != 0)
      && (((tags & 0x1) != 0) || ((tags & 0x2) != 0 && (tags & 0x8000_0000) != 0))
    {
      return true
    }

    if (attributes == 0x0 || attributes == 0x1)
      && ((tags & 0x1000_0000_0000_0000) != 0 || (tags & 0x300_0000_0000_0000) != 0)
      && (((tags & 0x1) != 0) || ((tags & 0x2) != 0 && (tags & 0x8000_0000) != 0))
    {
      return true
    }

    return false
  }
}

extension WindowServerClient: @unchecked Sendable {}

/// WindowServer display identifier and the spaces assigned to it.
struct WindowServerDisplaySpaces: Equatable {
  /// WindowServer display UUID.
  let id: String

  /// WindowServer space IDs assigned to the display.
  let spaces: [UInt64]
}
