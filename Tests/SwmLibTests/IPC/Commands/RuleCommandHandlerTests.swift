import Foundation
import Testing

@testable import SwmLib

@MainActor
@Suite("RuleCommandHandler")
struct RuleCommandHandlerTests {
  @Test("dispatch: validates mutations and lists indexed rules")
  func dispatchValidatesMutationsAndListsIndexedRules() throws {
    let tiling = makeTiling()
    let handler = RuleCommandHandler(tiling: tiling)
    func send(_ command: String, _ args: [String] = []) -> IPCResponse {
      handler.dispatch(IPCRequest(domain: .rule, command: command, args: args))
    }
    #expect(send("--add", ["label=test", "manage=off"]).ok)
    #expect(!send("--add", ["label=test", "manage=on"]).ok)
    #expect(!send("--add", ["app=[", "manage=off"]).ok)
    #expect(tiling.rules.count == 1)
    let listing = send("--list")
    #expect(listing.ok)
    let payload = try #require(
      JSONSerialization.jsonObject(with: Data(listing.message.utf8)) as? [[String: Any]]
    )
    #expect(payload.first?["index"] as? Int == 1)
    #expect((payload.first?["rule"] as? [String: String])?["label"] == "test")
    #expect(!send("--list", ["extra"]).ok)
    #expect(!send("--remove", [String(Int.min)]).ok)
    #expect(!send("--remove", ["0"]).ok)
    #expect(!send("--remove", ["missing"]).ok)
    #expect(!send("--remove", ["test", "extra"]).ok)
    #expect(!send("--unknown").ok)
    #expect(send("--remove", ["test"]).ok)
    #expect(tiling.rules.isEmpty)
    #expect(send("--add", ["label=a", "manage=off"]).ok)
    #expect(send("--add", ["label=b", "manage=off"]).ok)
    #expect(!send("--clear", ["extra"]).ok)
    #expect(send("--clear").ok)
    #expect(tiling.rules.isEmpty)
    #expect(send("--add", ["label=a", "manage=off"]).ok)
  }
}
