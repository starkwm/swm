import Foundation

struct QueryCommandHandler {
  private let windowManager: WindowManager

  init(windowManager: WindowManager = WindowManager(workspace: Workspace())) {
    self.windowManager = windowManager
  }

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

  func response<T: Encodable>(id: String, payload: T) throws -> IPCResponse {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    let data = try encoder.encode(payload)

    return .success(id: id, message: String(decoding: data, as: UTF8.self))
  }

  func response<T: Encodable>(id: String, result: QueryResult<T>) throws -> IPCResponse {
    switch result {
    case .many(let values):
      try response(id: id, payload: values)
    case .one(let value):
      try response(id: id, payload: value)
    }
  }
}
