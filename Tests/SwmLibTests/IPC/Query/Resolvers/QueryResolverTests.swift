import Testing

@testable import SwmLib

@Suite("QueryResolver")
struct QueryResolverTests {
  @Test("displays(for:): resolves display selectors")
  func displaysForResolvesDisplaySelectors() throws {
    let resolver = queryResolver()

    #expect(try many(resolver.displays(for: .none)).map(\.index) == [0, 1])
    #expect(try one(resolver.displays(for: .display(nil)))?.index == 0)
    #expect(try one(resolver.displays(for: .display(1)))?.index == 1)
    #expect(try one(resolver.displays(for: .space(nil)))?.index == 0)
    #expect(try one(resolver.displays(for: .space(1)))?.index == 1)
    #expect(try one(resolver.displays(for: .window(nil)))?.index == 0)
    #expect(try one(resolver.displays(for: .window(200)))?.index == 1)
  }

  @Test("spaces(for:): resolves space selectors")
  func spacesForResolvesSpaceSelectors() throws {
    let resolver = queryResolver()

    #expect(try many(resolver.spaces(for: .none)).map(\.index) == [0, 1])
    #expect(try many(resolver.spaces(for: .display(nil))).map(\.index) == [0])
    #expect(try many(resolver.spaces(for: .display(1))).map(\.index) == [1])
    #expect(try one(resolver.spaces(for: .space(nil)))?.index == 0)
    #expect(try one(resolver.spaces(for: .space(1)))?.index == 1)
    #expect(try one(resolver.spaces(for: .window(nil)))?.index == 0)
    #expect(try one(resolver.spaces(for: .window(200)))?.index == 1)
  }

  @Test("windows(for:): resolves window selectors")
  func windowsForResolvesWindowSelectors() throws {
    let resolver = queryResolver()

    #expect(try many(resolver.windows(for: .none)).map(\.id) == [100, 200])
    #expect(try many(resolver.windows(for: .display(nil))).map(\.id) == [100])
    #expect(try many(resolver.windows(for: .display(1))).map(\.id) == [200])
    #expect(try many(resolver.windows(for: .space(nil))).map(\.id) == [100])
    #expect(try many(resolver.windows(for: .space(1))).map(\.id) == [200])
    #expect(try one(resolver.windows(for: .window(nil)))?.id == 100)
    #expect(try one(resolver.windows(for: .window(200)))?.id == 200)
    #expect(try one(resolver.windows(for: .window(999))) == nil)
  }

  private func queryResolver() -> QueryResolver {
    QueryResolver(
      displays: [
        display(index: 0, id: "display-0", hasFocus: true),
        display(index: 1, id: "display-1", hasFocus: false),
      ],
      spaces: [
        space(index: 0, id: 10, display: "display-0", hasFocus: true),
        space(index: 1, id: 20, display: "display-1", hasFocus: false),
      ],
      windows: [
        window(id: 100, display: "display-0", space: 0, hasFocus: true),
        window(id: 200, display: "display-1", space: 1, hasFocus: false),
      ]
    )
  }

  private func display(index: Int, id: String, hasFocus: Bool) -> QueryDisplay {
    QueryDisplay(
      id: id,
      uuid: nil,
      index: index,
      frame: QueryFrame(.zero),
      spaces: [],
      hasFocus: hasFocus
    )
  }

  private func space(index: Int, id: UInt64, display: String, hasFocus: Bool) -> QuerySpace {
    QuerySpace(
      id: id,
      uuid: nil,
      index: index,
      label: nil,
      type: "normal",
      display: display,
      windows: [],
      hasFocus: hasFocus,
      isVisible: hasFocus,
      isNativeFullscreen: false
    )
  }

  private func window(id: UInt32, display: String, space: Int, hasFocus: Bool) -> QueryWindow {
    QueryWindow(
      id: id,
      pid: nil,
      app: nil,
      title: nil,
      frame: nil,
      role: nil,
      subrole: nil,
      display: display,
      space: space,
      layer: nil,
      subLayer: nil,
      canMove: nil,
      canResize: nil,
      hasFocus: hasFocus,
      hasAXReference: false,
      isNativeFullscreen: false,
      isVisible: nil,
      isMinimized: nil,
      isFloating: nil
    )
  }

  private func many<T>(_ result: QueryResult<T>) throws -> [T] {
    switch result {
    case .many(let values):
      values
    case .one:
      try #require(nil)
    }
  }

  private func one<T>(_ result: QueryResult<T>) throws -> T? {
    switch result {
    case .many:
      try #require(nil)
    case .one(let value):
      value
    }
  }
}
