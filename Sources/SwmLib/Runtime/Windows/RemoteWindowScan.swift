import CoreGraphics

struct RemoteWindowScan: Equatable {
  private(set) var cursor = WindowDiscoveryCursor()

  private(set) var exhaustedWindowIDs = Set<CGWindowID>()

  private var cycleWindowIDs: Set<CGWindowID>?

  func scannableWindowIDs(_ unresolvedWindowIDs: [CGWindowID]) -> [CGWindowID] {
    unresolvedWindowIDs.filter { !exhaustedWindowIDs.contains($0) }
  }

  mutating func retainWindows(_ liveWindowIDs: Set<CGWindowID>) {
    exhaustedWindowIDs.formIntersection(liveWindowIDs)
    cycleWindowIDs?.formIntersection(liveWindowIDs)
  }

  mutating func nextBatch(for windowIDs: [CGWindowID]) -> ClosedRange<Int> {
    if cursor.nextTokenID == 0 { cycleWindowIDs = Set(windowIDs) }
    return cursor.nextBatch()
  }

  mutating func finishBatch(unresolved windowIDs: [CGWindowID]) {
    cycleWindowIDs?.formIntersection(windowIDs)
    guard cursor.nextTokenID == 0 else { return }
    exhaustedWindowIDs.formUnion(cycleWindowIDs ?? [])
    cycleWindowIDs = nil
  }

  mutating func restartCycle() {
    cursor = WindowDiscoveryCursor()
    cycleWindowIDs = nil
  }
}
