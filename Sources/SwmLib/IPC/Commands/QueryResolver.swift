import CoreGraphics

struct QueryResolver {
  let displays: [DisplaySerializer]
  let spaces: [SpaceSerializer]
  let windows: [WindowSerializer]

  init(windowManager: WindowManager) {
    self.init(
      displays: DisplaySerializer.all(),
      spaces: SpaceSerializer.all(windowManager: windowManager),
      windows: WindowSerializer.all(windowManager: windowManager)
    )
  }

  init(
    displays: [DisplaySerializer],
    spaces: [SpaceSerializer],
    windows: [WindowSerializer]
  ) {
    self.displays = displays
    self.spaces = spaces
    self.windows = windows
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
      return .many(spaces.filter { $0.display == display.id })
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
    displays.first { $0.id == space.display }
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
