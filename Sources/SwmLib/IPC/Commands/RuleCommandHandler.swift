@MainActor
struct RuleCommandHandler {
  let tiling: Tiling

  var reload: ConfigReload?

  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      let staging = reload?.staging(for: request)
      switch request.command {
      case "--add":
        let rule = try WindowRule.parse(arguments: request.args)
        if let staging { try staging.addRule(rule) } else { try tiling.addRule(rule) }
      case "--remove":
        let selector = try IPCArguments(request.args, context: "rule remove").requiredValue()
        if let staging {
          try staging.removeRule(selector: selector)
        } else {
          try tiling.removeRule(selector: selector)
        }
      case "--clear":
        try IPCArguments(request.args, context: "rule clear").requireEmpty()
        if let staging { staging.removeAllRules() } else { tiling.removeAllRules() }
      case "--list":
        try IPCArguments(request.args, context: "rule list").requireEmpty()
        return try .json(
          id: request.id,
          payload: (staging?.rules ?? tiling.rules).enumerated().map {
            IndexedRule(index: $0.offset + 1, rule: $0.element)
          }
        )
      default:
        throw IPCCommandError.unsupportedCommand("unsupported rule command: \(request.command)")
      }
      return .acknowledged(id: request.id)
    }
  }
}

private struct IndexedRule: Encodable {
  let index: Int
  let rule: WindowRule
}
