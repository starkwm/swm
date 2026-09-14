/// Manage rules on the same actor as window reconciliation.
@MainActor
struct RuleCommandHandler {
  let tiling: Tiling

  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "--add":
        try tiling.addRule(WindowRule.parse(arguments: request.args))
      case "--remove":
        let selector = try IPCArguments(request.args, context: "rule remove").requiredValue()
        try tiling.removeRule(selector: selector)
      case "--list":
        try IPCArguments(request.args, context: "rule list").requireEmpty()
        return try .json(
          id: request.id,
          payload: tiling.rules.enumerated().map {
            IndexedRule(index: $0.offset + 1, rule: $0.element)
          }
        )
      default:
        throw IPCCommandError.unsupportedCommand("unsupported rule command: \(request.command)")
      }
      return .success(id: request.id, message: "ok")
    }
  }
}

private struct IndexedRule: Encodable {
  let index: Int
  let rule: WindowRule
}
