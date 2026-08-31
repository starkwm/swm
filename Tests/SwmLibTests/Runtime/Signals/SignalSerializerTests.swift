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

  @Test("encode: describes normal and inverted filters")
  func encodeDescribesNormalAndInvertedFilters() throws {
    let signal = Signal(
      label: "focus-log",
      event: .windowFocused,
      action: "echo focus",
      appFilter: try SignalTextFilter(pattern: "Safari"),
      titleFilter: try SignalTextFilter(pattern: "Private", inverted: true),
      active: true
    )

    let object = try encodedObject(SignalSerializer(indexedSignal: indexed(signal, index: 3)))

    #expect(object["index"] as? Int == 3)
    #expect(object["label"] as? String == "focus-log")
    #expect(object["app"] as? String == "Safari")
    #expect(object["title"] as? String == "!Private")
    #expect(object["active"] as? Bool == true)
    #expect(object["event"] as? String == "window-focused")
    #expect(object["action"] as? String == "echo focus")
  }

  private func indexed(_ signal: Signal, index: Int = 1) -> IndexedSignal {
    IndexedSignal(index: index, signal: signal)
  }
}
