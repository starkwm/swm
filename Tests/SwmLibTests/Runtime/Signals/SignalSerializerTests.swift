import Foundation
import Testing

@testable import SwmLib

@Suite("SignalSerializer")
struct SignalSerializerTests {
  @Test("encode: uses nullable fields for missing filters")
  func encodeUsesNullableFieldsForMissingFilters() throws {
    let signal = Signal(
      label: nil,
      event: .displayChanged,
      action: "echo display",
      appFilter: nil,
      titleFilter: nil,
      active: nil
    )

    let object = try encodedObject(SignalSerializer(indexedSignal: indexed(signal)))

    #expect(object["index"] as? Int == 1)
    #expect(object["label"] is NSNull)
    #expect(object["app"] is NSNull)
    #expect(object["title"] is NSNull)
    #expect(object["active"] is NSNull)
    #expect(object["event"] as? String == "display-changed")
    #expect(object["action"] as? String == "echo display")
  }

  private func indexed(_ signal: Signal, index: Int = 1) -> IndexedSignal {
    IndexedSignal(index: index, signal: signal)
  }
}
