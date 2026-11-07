import ApplicationServices
import Testing

@testable import SwmLib

@Suite("AccessibilityRead")
struct AccessibilityReadTests {
  @Test(
    "init: keeps failed reads distinct from confirmed values",
    arguments: [
      (AXError.success, "read"),
      (.attributeUnsupported, "absent"),
      (.noValue, "absent"),
      (.cannotComplete, nil),
      (.apiDisabled, nil),
      (.invalidUIElement, nil),
      (.failure, nil),
    ] as [(AXError, String?)]
  )
  func initKeepsFailedReadsDistinctFromConfirmedValues(error: AXError, expected: String?) {
    let read = AccessibilityRead(error, value: { "read" }, absent: "absent")
    #expect(read.value == expected)
    #expect(read.isUnavailable == (expected == nil))
  }
}
