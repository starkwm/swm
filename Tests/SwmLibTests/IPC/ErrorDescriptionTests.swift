import Testing

@testable import SwmLib

@Suite("ErrorDescription")
struct ErrorDescriptionTests {
  @Test("config errors describe failures")
  func configErrorsDescribeFailures() {
    #expect(ConfigError.fileDoesNotExist.description == "configuration file does not exist")
    #expect(
      ConfigError.unableToMakeExecutable.description
        == "unable to mark the configuration file as executable"
    )
    #expect(ConfigError.unableToExecute.description == "unable to execute the configuration file")
  }

  @Test("lock file errors describe failures")
  func lockFileErrorsDescribeFailures() {
    #expect(LockFileError.failedToOpenFile.description == "failed to open lockfile")
    #expect(LockFileError.failedToLockFile.description == "failed to lock lockfile")
  }

  @Test("unix socket errors describe failures")
  func unixSocketErrorsDescribeFailures() {
    #expect(
      UnixSocketError.frameTooLarge(1024).description
        == "IPC frame exceeded maximum size of 1024 bytes"
    )
    #expect(
      UnixSocketError.socketAlreadyInUse("/tmp/swm.sock").description
        == "socket is already in use at /tmp/swm.sock"
    )
  }

  @Test("daemon errors describe failures")
  func daemonErrorsDescribeFailures() {
    #expect(
      DaemonError.unableToPrepareSocket("busy").description
        == "unable to prepare listening socket - busy"
    )
    #expect(DaemonError.unableToCreateSocket.description == "unable to create listening socket")
    #expect(DaemonError.unableToUnwrapSocket.description == "unable to unwrap listening socket")
    #expect(
      DaemonError.unableToListenOnSocket.description == "unable to listen on listening socket"
    )
  }
}
