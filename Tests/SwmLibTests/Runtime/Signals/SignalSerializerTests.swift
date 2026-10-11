import Foundation
import Testing

@testable import SwmLib

@Suite("SignalSerializer")
struct SignalSerializerTests {
  @Test("encode: represents an unlabeled registration as null")
  func encodeRepresentsAnUnlabeledRegistrationAsNull() throws {
    let signal = try Signal.parseAdd(arguments: ["event=display-changed", "action=echo display"])
    let object = try encodedObject(
      SignalSerializer(indexedSignal: IndexedSignal(index: 1, signal: signal))
    )
    #expect(object["label"] is NSNull)
  }
}
