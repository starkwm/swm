@MainActor
struct RuleCommandHandler {
  let tiling: Tiling

  var reload: ConfigReload?

  func dispatch(_ request: IPCRequest, command: IPCCommand.Rule) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      let staging = reload?.staging(for: request)
      switch command {
      case .add(let arguments):
        let rule = try WindowRule.parse(arguments: arguments)
        if let staging { try staging.addRule(rule) } else { try tiling.addRule(rule) }
      case .remove(let selector):
        if let staging {
          try staging.removeRule(selector: selector)
        } else {
          try tiling.removeRule(selector: selector)
        }
      case .clear:
        if let staging { staging.removeAllRules() } else { tiling.removeAllRules() }
      case .list:
        return try .json(
          id: request.id,
          payload: (staging?.rules ?? tiling.rules).enumerated().map {
            IndexedRule(index: $0.offset + 1, rule: $0.element)
          }
        )
      }
      return .acknowledged(id: request.id)
    }
  }
}

private struct IndexedRule: Encodable {
  let index: Int
  let rule: WindowRule
}
