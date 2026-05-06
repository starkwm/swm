struct IPCCommandError: Error, Equatable, CustomStringConvertible {
  let message: String
  let errorCode: IPCErrorCode

  static func invalidRequest(_ message: String) -> IPCCommandError {
    IPCCommandError(message: message, errorCode: .invalidRequest)
  }

  static func unsupportedCommand(_ message: String) -> IPCCommandError {
    IPCCommandError(message: message, errorCode: .unsupportedCommand)
  }

  static func internalError(_ message: String) -> IPCCommandError {
    IPCCommandError(message: message, errorCode: .internalError)
  }

  static func catching(id: String, _ action: () throws -> IPCResponse) -> IPCResponse {
    do {
      return try action()
    } catch let error as IPCCommandError {
      return error.response(id: id)
    } catch {
      return IPCCommandError.internalError("\(error)").response(id: id)
    }
  }

  var description: String {
    message
  }

  func response(id: String) -> IPCResponse {
    .failure(id: id, message: message, errorCode: errorCode)
  }
}
