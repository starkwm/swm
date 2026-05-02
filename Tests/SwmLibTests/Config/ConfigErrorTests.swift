import Testing

@testable import SwmLib

@Suite("ConfigError")
struct ConfigErrorTests {
  @Test("config errors describe failures")
  func configErrorsDescribeFailures() {
    #expect(ConfigError.fileDoesNotExist.description == "configuration file does not exist")
    #expect(
      ConfigError.unableToMakeExecutable.description
        == "unable to mark the configuration file as executable"
    )
    #expect(ConfigError.unableToExecute.description == "unable to execute the configuration file")
  }
}
