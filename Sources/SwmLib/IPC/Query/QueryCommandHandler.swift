import Foundation

struct QueryCommandHandler {
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    do {
      let selection = try QuerySelection.parse(arguments: request.args)
      let resolver = QueryResolver()

      switch request.command {
      case "--displays":
        return try response(id: request.id, result: resolver.displays(for: selection))
      case "--windows":
        return try response(id: request.id, result: resolver.windows(for: selection))
      case "--spaces":
        return try response(id: request.id, result: resolver.spaces(for: selection))
      default:
        return .failure(
          id: request.id,
          message: "unsupported query command: \(request.command)",
          errorCode: .unsupportedCommand
        )
      }
    } catch {
      return .failure(id: request.id, message: "error: \(error)", errorCode: .internalError)
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
