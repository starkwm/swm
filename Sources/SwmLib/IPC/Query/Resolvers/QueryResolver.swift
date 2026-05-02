import CoreGraphics

struct QueryResolver {
  let displays: [QueryDisplay]
  let spaces: [QuerySpace]
  let windows: [QueryWindow]

  init(
    displays: [QueryDisplay] = QueryDisplay.all(),
    spaces: [QuerySpace] = QuerySpace.all(),
    windows: [QueryWindow] = QueryWindow.all()
  ) {
    self.displays = displays
    self.spaces = spaces
    self.windows = windows
  }

  func displays(for selection: QuerySelection) -> QueryResult<QueryDisplay> {
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

  func spaces(for selection: QuerySelection) -> QueryResult<QuerySpace> {
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

  func windows(for selection: QuerySelection) -> QueryResult<QueryWindow> {
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

  private func display(for index: Int?) -> QueryDisplay? {
    if let index {
      displays.first { $0.index == index }
    } else {
      displays.first { $0.hasFocus }
    }
  }

  private func space(for index: Int?) -> QuerySpace? {
    if let index {
      spaces.first { $0.index == index }
    } else {
      spaces.first { $0.hasFocus }
    }
  }

  private func window(for id: CGWindowID?) -> QueryWindow? {
    if let id {
      windows.first { $0.id == id }
    } else {
      windows.first { $0.hasFocus == true }
    }
  }

  private func display(containing space: QuerySpace) -> QueryDisplay? {
    displays.first { $0.id == space.display }
  }

  private func display(containing window: QueryWindow) -> QueryDisplay? {
    guard let displayID = window.display else { return nil }
    return displays.first { $0.id == displayID }
  }

  private func space(containing window: QueryWindow) -> QuerySpace? {
    guard let spaceIndex = window.space else { return nil }
    return spaces.first { $0.index == spaceIndex }
  }
}
