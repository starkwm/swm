/// Handles IPC requests that query displays, spaces, and windows.
@MainActor
struct QueryCommandHandler {
  private let windowManager: Windows

  /// Create a query command handler backed by a window manager.
  init(windowManager: Windows) {
    self.windowManager = windowManager
  }

  /// Dispatch a query IPC request and encode the selected result as JSON.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      let selection = try QuerySelection.parse(arguments: request.args)
      let resolver = QueryResolver(windowManager: windowManager)

      switch request.command {
      case "--displays":
        return try response(id: request.id, result: resolver.displays(for: selection))
      case "--windows":
        return try response(id: request.id, result: resolver.windows(for: selection))
      case "--spaces":
        return try response(id: request.id, result: resolver.spaces(for: selection))
      default:
        throw IPCCommandError.unsupportedCommand("unsupported query command: \(request.command)")
      }
    }
  }

  /// Encode either a single query value or a list of query values.
  private func response<T: Encodable>(id: String, result: QueryResult<T>) throws -> IPCResponse {
    switch result {
    case .many(let values):
      try .json(id: id, payload: values)
    case .one(let value):
      try .json(id: id, payload: value)
    }
  }
}
