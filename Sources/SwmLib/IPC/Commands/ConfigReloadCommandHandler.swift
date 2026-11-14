import Foundation

/// Handles the config commands that open, commit, and roll back a configuration reload.
@MainActor
struct ConfigReloadCommandHandler {
  /// Config commands this handler owns.
  static let commands: Set = ["--begin-reload", "--commit-reload", "--rollback-reload"]

  let reload: ConfigReload

  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      let context = "config \(request.command.dropFirst(2))"
      let value = try IPCArguments(request.args, context: context).requiredValue()
      switch request.command {
      case "--begin-reload":
        guard let processID = pid_t(value), processID > 0 else {
          throw IPCCommandError.invalidRequest("invalid reload process ID: \(value)")
        }
        return .success(id: request.id, message: try reload.begin(processID: processID))
      case "--commit-reload":
        try reload.commit(token: value)
      case "--rollback-reload":
        try reload.rollback(token: value)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported config command: \(request.command)")
      }
      return .acknowledged(id: request.id)
    }
  }
}
