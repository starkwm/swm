import AppKit
import CHIServices
import CSkyLight
import Carbon
import CoreGraphics
import Darwin
import StarkSkyLight

final class WindowServerClient {
  static let shared = WindowServerClient()

  @MainActor
  static let spaceClient = Result { try SpaceClient() }

  static func sameProcess(_ lhs: ProcessSerialNumber, _ rhs: ProcessSerialNumber) -> Bool {
    lhs.highLongOfPSN == rhs.highLongOfPSN && lhs.lowLongOfPSN == rhs.lowLongOfPSN
  }

  func mainConnectionID() -> Int32 {
    SLSMainConnectionID()
  }

  func frontmostProcessID() -> pid_t? {
    var psn = ProcessSerialNumber()
    guard _SLPSGetFrontProcess(&psn) == noErr else { return nil }

    var pid = pid_t()
    guard SWMGetProcessPID(&psn, &pid) == noErr else { return nil }

    return pid
  }

  func frontmostWindowID(at point: CGPoint) -> CGWindowID? {
    frontmostWindowAndOwner(at: point)?.windowID
  }

  func focusFrontmostWindow(at point: CGPoint) -> Bool {
    guard let (windowID, connectionID) = frontmostWindowAndOwner(at: point) else { return false }

    var processSerialNumber = ProcessSerialNumber()
    guard SLSGetConnectionPSN(connectionID, &processSerialNumber) == .success else { return false }

    return focusWindowWithoutRaise(
      processSerialNumber: processSerialNumber,
      windowID: windowID,
      currentProcessSerialNumber: nil,
      currentWindowID: nil
    )
  }

  func onScreenWindowIDs() -> [CGWindowID] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard
      let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
    else {
      return []
    }

    return windows.compactMap { $0[kCGWindowNumber as String] as? CGWindowID }
  }

  func focusWindowWithoutRaise(
    processSerialNumber: ProcessSerialNumber,
    windowID: CGWindowID,
    currentProcessSerialNumber: ProcessSerialNumber?,
    currentWindowID: CGWindowID?
  ) -> Bool {
    var processSerialNumber = processSerialNumber

    if var currentProcessSerialNumber,
      let currentWindowID,
      Self.sameProcess(currentProcessSerialNumber, processSerialNumber)
    {
      guard
        postFocusTransition(
          from: currentWindowID,
          to: windowID,
          processSerialNumber: &currentProcessSerialNumber
        )
      else {
        return false
      }
    }

    guard
      _SLPSSetFrontProcessWithOptions(
        &processSerialNumber,
        windowID,
        0x200
      ) == .success
    else {
      return false
    }

    return postMakeKeyWindow(windowID, processSerialNumber: &processSerialNumber)
  }

  func connectionID(for psn: ProcessSerialNumber) -> Int32? {
    var psn = psn
    var connectionID: Int32 = -1

    guard SLSGetConnectionIDForPSN(mainConnectionID(), &psn, &connectionID) == .success else {
      return nil
    }

    return connectionID > 0 ? connectionID : nil
  }

  @MainActor
  func spaceSnapshot() throws -> SpaceSnapshot {
    try Self.spaceClient.get().snapshot()
  }

  @MainActor
  func spaceSnapshotIfAvailable() -> SpaceSnapshot? {
    querySpaces(default: nil) { try $0.snapshot() }
  }

  @MainActor
  func activeSpace() -> UInt64? {
    querySpaces(default: nil) { try $0.activeSpace()?.rawValue }
  }

  @MainActor
  func allSpaceIDs() -> [UInt64] {
    querySpaces(default: []) { try $0.snapshot().allSpaceIDs.map(\.rawValue) }
  }

  @MainActor
  func screenID(for spaceID: UInt64) -> String? {
    querySpaces(default: nil) {
      try $0.snapshot().displayID(containing: .init(rawValue: spaceID))?.rawValue
    }
  }

  @MainActor
  func spaceIDs(containing windowID: CGWindowID) -> [UInt64] {
    querySpaces(default: []) { try $0.spaceIDs(containing: windowID).map(\.rawValue) }
  }

  @MainActor
  func spaceType(for spaceID: UInt64) -> SpaceType {
    guard spaceID != 0 else { return .unknown }
    return querySpaces(default: .unknown) {
      SpaceType(try $0.spaceType(for: .init(rawValue: spaceID)))
    }
  }

  func windowIdentifiers(
    applicationConnectionID: Int32,
    spaceIDs: [UInt64]
  ) -> [CGWindowID] {
    guard let connectionID = UInt32(exactly: applicationConnectionID), connectionID != 0 else {
      return []
    }
    let spaces = spaceIDs as CFArray
    let options: UInt32 = 0x7
    var setTags: UInt64 = 0
    var clearTags: UInt64 = 0

    guard
      let windows = SLSCopyWindowsWithOptionsAndTags(
        mainConnectionID(),
        connectionID,
        spaces,
        options,
        &setTags,
        &clearTags
      ),
      let query = SLSWindowQueryWindows(
        mainConnectionID(),
        windows,
        Int32(clamping: CFArrayGetCount(windows))
      ),
      let iterator = SLSWindowQueryResultCopyWindows(query)
    else {
      return []
    }

    var windowIDs = [CGWindowID]()

    while SLSWindowIteratorAdvance(iterator) {
      guard SLSWindowIteratorGetParentID(iterator) == 0 else { continue }

      let level = NSWindow.Level(rawValue: Int(SLSWindowIteratorGetLevel(iterator)))
      guard level == .normal || level == .floating || level == .modalPanel else { continue }

      let attributes = SLSWindowIteratorGetAttributes(iterator)
      let tags = SLSWindowIteratorGetTags(iterator)
      guard validWindow(attributes: attributes, tags: tags) else { continue }

      let id = SLSWindowIteratorGetWindowID(iterator)
      windowIDs.append(id)
    }

    return windowIDs
  }

  private func frontmostWindowAndOwner(at point: CGPoint) -> (
    windowID: CGWindowID, connectionID: Int32
  )? {
    var screenPoint = point
    var windowPoint = CGPoint.zero
    var windowID = CGWindowID()
    var windowConnectionID = Int32()

    guard
      SLSFindWindowAndOwner(
        mainConnectionID(),
        0,
        1,
        0,
        &screenPoint,
        &windowPoint,
        &windowID,
        &windowConnectionID
      ) == noErr,
      windowID != 0
    else {
      return nil
    }

    return (windowID, windowConnectionID)
  }

  @MainActor
  private func querySpaces<Value>(default fallback: Value, _ query: (SpaceClient) throws -> Value)
    -> Value
  {
    do {
      return try query(Self.spaceClient.get())
    } catch {
      log("could not query Spaces: \(error)", level: .warn)
      return fallback
    }
  }

  private func postMakeKeyWindow(
    _ windowID: CGWindowID,
    processSerialNumber: inout ProcessSerialNumber
  ) -> Bool {
    var event = eventRecord(for: windowID)

    event[0x08] = 0x01
    guard postEventRecord(&event, processSerialNumber: &processSerialNumber) else { return false }

    event[0x08] = 0x02
    return postEventRecord(&event, processSerialNumber: &processSerialNumber)
  }

  private func postFocusTransition(
    from currentWindowID: CGWindowID,
    to windowID: CGWindowID,
    processSerialNumber: inout ProcessSerialNumber
  ) -> Bool {
    var event = [UInt8](repeating: 0, count: 0xf8)
    event[0x04] = 0xf8
    event[0x08] = 0x0d

    event[0x8a] = 0x02
    copy(currentWindowID, to: &event, at: 0x3c)
    guard postEventRecord(&event, processSerialNumber: &processSerialNumber) else { return false }

    Darwin.usleep(40_000)

    event[0x8a] = 0x01
    copy(windowID, to: &event, at: 0x3c)
    return postEventRecord(&event, processSerialNumber: &processSerialNumber)
  }

  private func eventRecord(for windowID: CGWindowID) -> [UInt8] {
    var event = [UInt8](repeating: 0, count: 0xf8)
    event[0x04] = 0xf8
    event[0x3a] = 0x10
    event.replaceSubrange(0x20..<0x30, with: repeatElement(UInt8.max, count: 0x10))
    copy(windowID, to: &event, at: 0x3c)
    return event
  }

  private func copy(_ windowID: CGWindowID, to event: inout [UInt8], at offset: Int) {
    withUnsafeBytes(of: windowID) { bytes in
      event.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
    }
  }

  private func postEventRecord(
    _ event: inout [UInt8],
    processSerialNumber: inout ProcessSerialNumber
  ) -> Bool {
    event.withUnsafeMutableBufferPointer { buffer in
      guard let baseAddress = buffer.baseAddress else { return false }
      return SLPSPostEventRecordTo(&processSerialNumber, baseAddress) == .success
    }
  }

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
