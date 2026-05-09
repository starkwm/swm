/// A command-level IPC failure that can be converted into an IPC response.
struct IPCCommandError: Error, Equatable, CustomStringConvertible {
  /// Create an error for malformed or incomplete client input.
  static func invalidRequest(_ message: String) -> IPCCommandError {
    IPCCommandError(message: message, errorCode: .invalidRequest)
  }

  /// Create an error for a well-formed command that is not supported.
  static func unsupportedCommand(_ message: String) -> IPCCommandError {
    IPCCommandError(message: message, errorCode: .unsupportedCommand)
  }

  /// Create an error for a command that failed while being processed.
  static func internalError(_ message: String) -> IPCCommandError {
    IPCCommandError(message: message, errorCode: .internalError)
  }

  /// Run a command action and convert thrown errors into failure responses.
  static func catching(id: String, _ action: () throws -> IPCResponse) -> IPCResponse {
    do {
      return try action()
    } catch let error as IPCCommandError {
      return error.response(id: id)
    } catch {
      return IPCCommandError.internalError("\(error)").response(id: id)
    }
  }

  /// Human-readable error message returned to the IPC client.
  let message: String

  /// Machine-readable error code returned to the IPC client.
  let errorCode: IPCErrorCode

  /// Human-readable description of the command failure.
  var description: String {
    message
  }

  /// Convert the error into an IPC failure response.
  func response(id: String) -> IPCResponse {
    .failure(id: id, message: message, errorCode: errorCode)
  }
}
