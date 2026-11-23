import Testing

@testable import Swm
@testable import SwmLib

@MainActor
@Suite("Padding CLI behavior")
struct PaddingCommandTests {
  @Test(
    "uniform and per-side values reach the selected settings",
    arguments: ["global", "current", "2"]
  )
  func uniformAndPerSideValuesReachSelectedSettings(scope: String) async throws {
    let spaces = Spaces(activeSpaceID: 10)
    let windows = Windows(workspace: Workspace(), focusedWindowID: nil)
    let tiling = Tiling(
      snapshot: { TilingReconciliationSnapshot(windows: [], topology: nil) },
      spaces: spaces
    )
    let config = ConfigCommandHandler(windows: windows, spaces: spaces, tiling: tiling)
    let space = SpaceCommandHandler(
      spaces: spaces,
      tiling: tiling,
      spaceIDProvider: { [10, 20] }
    )
    let initial = SpacePadding(top: 10, bottom: 20, left: 30, right: 40)
    spaces.updateAllSettings { $0.padding = initial }
    spaces.setPadding(SpacePadding(top: 1, bottom: 2, left: 3, right: 4), for: 10)

    func send(_ values: [String]) async throws -> IPCResponse {
      let selection = scope == "global" ? [] : ["--space", scope]
      let command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["config", "padding"] + selection + values))
          as? any IPCCommand
      )
      let request = IPCRequest(
        id: "padding",
        domain: command.requestDomain,
        command: command.commandArguments[0],
        args: Array(command.commandArguments.dropFirst())
      )
      return scope != "global" ? await space.dispatch(request) : config.dispatch(request)
    }

    #expect(try await send(["+2", "--top", "8"]).ok)
    let selected: UInt64 = scope == "2" ? 20 : 10
    #expect(
      spaces.settings(for: selected).padding
        == (scope == "current"
          ? SpacePadding(top: 8, bottom: 4, left: 5, right: 6)
          : SpacePadding(top: 8, bottom: 22, left: 32, right: 42))
    )
    #expect(try await send(["--top", "-2", "8"]).ok)
    #expect(
      spaces.settings(for: selected).padding
        == SpacePadding(top: 6, bottom: 8, left: 8, right: 8)
    )
    #expect(try await send(["-2", "--left", "12"]).ok)
    #expect(
      spaces.settings(for: selected).padding
        == SpacePadding(top: 4, bottom: 6, left: 12, right: 6)
    )
    #expect(try await send(["8"]).ok)
    #expect(try await send(["-10"]).ok)
    #expect(spaces.settings(for: selected).padding == .zero)
    #expect(try await send(["--right", "9"]).ok)
    #expect(try await send([]).message == "--top 0 --bottom 0 --left 0 --right 9")
    if scope != "global" {
      #expect(
        spaces.settings(for: scope == "current" ? 20 : 10).padding
          == (scope == "current" ? initial : SpacePadding(top: 1, bottom: 2, left: 3, right: 4))
      )
      #expect(spaces.settings(for: 30).padding == initial)
    } else {
      #expect(spaces.settings(for: 30).padding == spaces.settings(for: selected).padding)
    }
  }

  @Test("rejects malformed and extra positional values", arguments: ["global", "current", "2"])
  func rejectsMalformedAndExtraPositionalValues(scope: String) {
    for values in [["wide"], ["8", "9"], ["rel:2"], ["8", "--top", "wide"]] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(
          Arguments.resolve(
            ["config", "padding"] + (scope == "global" ? [] : ["--space", scope]) + values
          )
        )
      }
    }
  }
}
