import CoreGraphics

/// Remote-token scan state for one application.
///
/// Each pass scans one bounded batch of token IDs. A window still unresolved after a full
/// cycle of passes has no remote token, so later passes skip it instead of rescanning every
/// token on each app switch and Space change.
struct RemoteWindowScan: Equatable {
  /// Cursor over token IDs.
  private(set) var cursor = WindowDiscoveryCursor()

  /// Windows a full cycle of passes could not resolve.
  private(set) var exhaustedWindowIDs = Set<CGWindowID>()

  /// Windows unresolved by every pass since the current cycle started.
  private var cycleWindowIDs: Set<CGWindowID>?

  /// Return the unresolved windows that a pass can still resolve.
  func scannableWindowIDs(_ unresolvedWindowIDs: [CGWindowID]) -> [CGWindowID] {
    unresolvedWindowIDs.filter { !exhaustedWindowIDs.contains($0) }
  }

  /// Forget windows that no longer exist, so a reused ID is scanned again.
  mutating func retainWindows(_ liveWindowIDs: Set<CGWindowID>) {
    exhaustedWindowIDs.formIntersection(liveWindowIDs)
    cycleWindowIDs?.formIntersection(liveWindowIDs)
  }

  /// Return the token IDs for the next pass over the given unresolved windows.
  mutating func nextBatch(for windowIDs: [CGWindowID]) -> ClosedRange<Int> {
    if cursor.nextTokenID == 0 { cycleWindowIDs = Set(windowIDs) }
    return cursor.nextBatch()
  }

  /// Record the windows a pass left unresolved, exhausting those the whole cycle missed.
  mutating func finishBatch(unresolved windowIDs: [CGWindowID]) {
    cycleWindowIDs?.formIntersection(windowIDs)
    guard cursor.nextTokenID == 0 else { return }
    exhaustedWindowIDs.formUnion(cycleWindowIDs ?? [])
    cycleWindowIDs = nil
  }

  /// Start the next pass from the first token ID.
  mutating func restartCycle() {
    cursor = WindowDiscoveryCursor()
    cycleWindowIDs = nil
  }
}
