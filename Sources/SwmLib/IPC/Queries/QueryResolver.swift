import CoreGraphics

@MainActor
final class QueryResolver {
  private(set) lazy var displays = displayProvider()

  private(set) lazy var spaces = spaceProvider()

  private(set) lazy var windows = windowProvider()

  private let displayProvider: () -> [DisplaySerializer]
  private let spaceProvider: () -> [SpaceSerializer]
  private let windowProvider: () -> [WindowSerializer]

  init(windows: Windows, tiling: Tiling) {
    let snapshot = QuerySnapshot(windows: windows, tiling: tiling)
    displayProvider = { DisplaySerializer.all(snapshot: snapshot) }
    spaceProvider = { SpaceSerializer.all(snapshot: snapshot) }
    windowProvider = { WindowSerializer.all(snapshot: snapshot) }
  }

  init(
    displayProvider: @escaping () -> [DisplaySerializer],
    spaceProvider: @escaping () -> [SpaceSerializer],
    windowProvider: @escaping () -> [WindowSerializer]
  ) {
    self.displayProvider = displayProvider
    self.spaceProvider = spaceProvider
    self.windowProvider = windowProvider
  }

  convenience init(
    displays: [DisplaySerializer],
    spaces: [SpaceSerializer],
    windows: [WindowSerializer]
  ) {
    self.init(
      displayProvider: { displays },
      spaceProvider: { spaces },
      windowProvider: { windows }
    )
  }

  func displays(for selection: QuerySelection) -> QueryResult<DisplaySerializer> {
    switch selection {
    case .none:
      return .many(displays)
    case .display(let index):
      return .one(display(for: index))
    case .space(let index):
      return .one(space(for: index).flatMap(display(containing:)))
    case .window(let id):
      return .one(window(for: id).flatMap(display(containing:)))
    }
  }

  func spaces(for selection: QuerySelection) -> QueryResult<SpaceSerializer> {
    switch selection {
    case .none:
      return .many(spaces)
    case .display(let index):
      guard let display = display(for: index) else { return .many([]) }
      guard let displayID = display.id else { return .many([]) }
      return .many(spaces.filter { $0.displays.contains(displayID) })
    case .space(let index):
      return .one(space(for: index))
    case .window(let id):
      return .one(window(for: id).flatMap(space(containing:)))
    }
  }

  func windows(for selection: QuerySelection) -> QueryResult<WindowSerializer> {
    switch selection {
    case .none:
      return .many(windows)
    case .display(let index):
      guard let displayID = display(for: index)?.id else { return .many([]) }
      return .many(windows.filter { $0.display == displayID })
    case .space(let index):
      guard let spaceIndex = space(for: index)?.index else { return .many([]) }
      return .many(windows.filter { $0.space == spaceIndex })
    case .window(let id):
      return .one(window(for: id))
    }
  }

  private func display(for index: Int?) -> DisplaySerializer? {
    if let index {
      displays.first { $0.index == index }
    } else {
      displays.first { $0.hasFocus }
    }
  }

  private func space(for index: Int?) -> SpaceSerializer? {
    if let index {
      spaces.first { $0.index == index }
    } else {
      spaces.first { $0.hasFocus }
    }
  }

  private func window(for id: CGWindowID?) -> WindowSerializer? {
    if let id {
      windows.first { $0.id == id }
    } else {
      windows.first { $0.hasFocus == true }
    }
  }

  private func display(containing space: SpaceSerializer) -> DisplaySerializer? {
    displays.first { display in
      guard let displayID = display.id else { return false }
      return space.displays.contains(displayID)
    }
  }

  private func display(containing window: WindowSerializer) -> DisplaySerializer? {
    guard let displayID = window.display else { return nil }

    return displays.first { $0.id == displayID }
  }

  private func space(containing window: WindowSerializer) -> SpaceSerializer? {
    guard let spaceIndex = window.space else { return nil }

    return spaces.first { $0.index == spaceIndex }
  }
}
