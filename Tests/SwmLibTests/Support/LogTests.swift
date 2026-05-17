import Testing

@testable import SwmLib

@Suite("LogLevel")
struct LogLevelTests {
  @Test("comparison: orders levels by severity")
  func comparisonOrdersLevelsBySeverity() {
    #expect(LogLevel.debug < .info)
    #expect(LogLevel.info < .warn)
    #expect(LogLevel.warn < .error)
    #expect(!(LogLevel.error < .debug))
  }

  @Test("label: uppercases raw value")
  func labelUppercasesRawValue() {
    #expect(LogLevel.debug.label == "DEBUG")
    #expect(LogLevel.info.label == "INFO")
    #expect(LogLevel.warn.label == "WARN")
    #expect(LogLevel.error.label == "ERROR")
  }
}
