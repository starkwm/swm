import Testing

@testable import SwmLib

@Suite("ConfigError")
struct ConfigErrorTests {
  @Test("description: describes failures")
  func descriptionDescribesFailures() {
    #expect(ConfigError.fileDoesNotExist.description == "configuration file does not exist")
    #expect(
      ConfigError.unableToMakeExecutable.description
        == "unable to mark the configuration file as executable"
    )
    #expect(ConfigError.unableToExecute.description == "unable to execute the configuration file")
    #expect(
      ConfigError.configurationFailed(status: 7).description
        == "configuration file exited with status 7"
    )
  }
}
