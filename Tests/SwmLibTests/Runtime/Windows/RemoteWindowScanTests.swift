import CoreGraphics
import Testing

@testable import SwmLib

@Suite("RemoteWindowScan")
struct RemoteWindowScanTests {
  @Test("finishBatch: skips only windows that a whole cycle left unresolved")
  func finishBatchSkipsOnlyWindowsThatAWholeCycleLeftUnresolved() {
    var scan = RemoteWindowScan()
    var passes = 0

    repeat {
      let unresolved: [CGWindowID] = passes == 0 ? [1] : [1, 2]
      _ = scan.nextBatch(for: scan.scannableWindowIDs(unresolved))
      scan.finishBatch(unresolved: unresolved)
      passes += 1
    } while scan.cursor.nextTokenID != 0

    #expect(passes > 1)
    #expect(scan.scannableWindowIDs([1, 2]) == [2])

    repeat {
      _ = scan.nextBatch(for: scan.scannableWindowIDs([1, 2]))
      scan.finishBatch(unresolved: [1, 2])
    } while scan.cursor.nextTokenID != 0

    #expect(scan.scannableWindowIDs([1, 2]).isEmpty)
  }

  @Test("finishBatch: does not exhaust a window resolved during the cycle")
  func finishBatchDoesNotExhaustAWindowResolvedDuringTheCycle() {
    var scan = RemoteWindowScan()
    _ = scan.nextBatch(for: [1, 2])
    scan.finishBatch(unresolved: [1])
    while scan.cursor.nextTokenID != 0 {
      _ = scan.nextBatch(for: [1])
      scan.finishBatch(unresolved: [1])
    }

    #expect(scan.exhaustedWindowIDs == [1])
  }

  @Test("retainWindows: rescans a reused window ID")
  func retainWindowsRescansAReusedWindowID() {
    var scan = RemoteWindowScan()
    repeat {
      _ = scan.nextBatch(for: [1])
      scan.finishBatch(unresolved: [1])
    } while scan.cursor.nextTokenID != 0
    #expect(scan.scannableWindowIDs([1]).isEmpty)

    scan.retainWindows([])

    #expect(scan.scannableWindowIDs([1]) == [1])
  }
}
