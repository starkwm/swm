import AppKit

/// Handles IPC requests that query displays, spaces, windows, and logical layouts.
@MainActor
struct QueryCommandHandler {
  private let windows: Windows
  private let tiling: Tiling?

  /// Create a query command handler backed by the window service.
  init(windows: Windows, tiling: Tiling? = nil) {
    self.windows = windows
    self.tiling = tiling
  }

  /// Dispatch a query IPC request and encode the selected result as JSON.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      let selection = try QuerySelection.parse(arguments: request.args)
      let resolver = QueryResolver(windows: windows)

      switch request.command {
      case "--displays":
        return try response(id: request.id, result: resolver.displays(for: selection))
      case "--windows":
        return try response(id: request.id, result: resolver.windows(for: selection))
      case "--spaces":
        return try response(id: request.id, result: resolver.spaces(for: selection))
      case "--layouts":
        return try .json(id: request.id, payload: layouts(for: selection, resolver: resolver))
      default:
        throw IPCCommandError.unsupportedCommand("unsupported query command: \(request.command)")
      }
    }
  }

  private func layouts(for selection: QuerySelection, resolver: QueryResolver)
    -> [TilingLayoutSerializer]
  {
    let layouts = tiling?.layoutSnapshots() ?? []
    switch selection {
    case .none:
      return layouts
    case .space:
      guard case .one(let space?) = resolver.spaces(for: selection) else { return [] }
      return layouts.filter { $0.spaceID == space.id }
    case .display:
      guard case .one(let display?) = resolver.displays(for: selection),
        let displayID = display.id,
        let uuid = NSScreen.screens.first(where: { $0.id == displayID })?.uuid
      else { return [] }
      return layouts.filter { $0.displayID == uuid }
    case .window(let windowID):
      guard let windowID = windowID ?? windows.currentFocusedWindowID else { return [] }
      return layouts.filter { $0.columns.contains { $0.window == windowID } }
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
