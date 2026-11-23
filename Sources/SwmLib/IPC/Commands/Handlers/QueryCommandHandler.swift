@MainActor
struct QueryCommandHandler {
  private let windows: Windows
  private let tiling: Tiling

  init(windows: Windows, tiling: Tiling) {
    self.windows = windows
    self.tiling = tiling
  }

  func dispatch(id: String, kind: QueryKind, selection: QuerySelection) -> IPCResponse {
    IPCCommandError.catching(id: id) {
      let resolver = QueryResolver(windows: windows, tiling: tiling)

      switch kind {
      case .displays:
        return try response(id: id, result: resolver.displays(for: selection))
      case .windows:
        return try response(id: id, result: resolver.windows(for: selection))
      case .spaces:
        return try response(id: id, result: resolver.spaces(for: selection))
      }
    }
  }

  private func response<T: Encodable>(id: String, result: QueryResult<T>) throws -> IPCResponse {
    switch result {
    case .many(let values):
      try .json(id: id, payload: values)
    case .one(let value):
      try .json(id: id, payload: value)
    }
  }
}
