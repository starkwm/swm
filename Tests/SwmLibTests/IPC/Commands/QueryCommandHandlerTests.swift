import Foundation
import Testing

@testable import SwmLib

@MainActor
@Suite("QueryCommandHandler")
struct QueryCommandHandlerTests {
  @Test("dispatch: layout queries expose logical columns and filter by window without mutation")
  func scrollingLayoutQuery() throws {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.scrolling, for: 10)
    let handler = QueryCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: 3),
      tiling: tiling
    )
    let request = try IPCRequest.make(domain: .query, arguments: ["--layouts", "--window", "3"])

    let response = handler.dispatch(request)
    #expect(response.ok)
    let data = try #require(response.message.data(using: .utf8))
    let layouts = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    let layout = try #require(layouts.first)
    let columns = try #require(layout["columns"] as? [[String: Any]])
    let frame = try #require(columns.last?["frame"] as? [String: Double])

    #expect(layouts.count == 1)
    #expect(layout["layout"] as? String == "scrolling")
    #expect(layout["viewport-offset"] as? Double == 0)
    #expect(columns.map { $0["window"] as? UInt32 } == [1, 2, 3])
    #expect(columns.last?["is-parked"] as? Bool == true)
    #expect(frame["x"] == 1_000)
    #expect(tiling.layoutSnapshots().first { $0.spaceID == 10 }?.viewportOffset == 0)

    let missing = handler.dispatch(
      try IPCRequest.make(domain: .query, arguments: ["--layouts", "--window", "99"])
    )
    #expect(missing.ok)
    #expect(missing.message == "[]")
  }
}
