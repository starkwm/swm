import CoreGraphics

/// Resolves query selections against serialized display, space, and window state.
@MainActor
final class QueryResolver {
  /// Displays available to query.
  private(set) lazy var displays = displayProvider()

  /// Spaces available to query.
  private(set) lazy var spaces = spaceProvider()

  /// Windows available to query.
  private(set) lazy var windows = windowProvider()

  private let displayProvider: () -> [DisplaySerializer]
  private let spaceProvider: () -> [SpaceSerializer]
  private let windowProvider: () -> [WindowSerializer]

  /// Snapshot the current display, space, and window state for querying.
  init(windowManager: WindowManager) {
    let snapshot = QuerySnapshot(windowManager: windowManager)
    displayProvider = { DisplaySerializer.all(snapshot: snapshot) }
    spaceProvider = { SpaceSerializer.all(snapshot: snapshot) }
    windowProvider = { WindowSerializer.all(snapshot: snapshot) }
  }

  /// Create a resolver from lazy state providers.
  init(
    displayProvider: @escaping () -> [DisplaySerializer],
    spaceProvider: @escaping () -> [SpaceSerializer],
    windowProvider: @escaping () -> [WindowSerializer]
  ) {
    self.displayProvider = displayProvider
    self.spaceProvider = spaceProvider
    self.windowProvider = windowProvider
  }

  /// Create a resolver from pre-serialized state.
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

  /// Resolve displays matching a query selection.
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

  /// Resolve spaces matching a query selection.
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

  /// Resolve windows matching a query selection.
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

  /// Return the display at an index, or the focused display when no index is supplied.
  private func display(for index: Int?) -> DisplaySerializer? {
    if let index {
      displays.first { $0.index == index }
    } else {
      displays.first { $0.hasFocus }
    }
  }

  /// Return the space at an index, or the focused space when no index is supplied.
  private func space(for index: Int?) -> SpaceSerializer? {
    if let index {
      spaces.first { $0.index == index }
    } else {
      spaces.first { $0.hasFocus }
    }
  }

  /// Return the window with an ID, or the focused window when no ID is supplied.
  private func window(for id: CGWindowID?) -> WindowSerializer? {
    if let id {
      windows.first { $0.id == id }
    } else {
      windows.first { $0.hasFocus == true }
    }
  }

  /// Return the display that owns a space.
  private func display(containing space: SpaceSerializer) -> DisplaySerializer? {
    displays.first { display in
      guard let displayID = display.id else { return false }
      return space.displays.contains(displayID)
    }
  }

  /// Return the display that owns a window.
  private func display(containing window: WindowSerializer) -> DisplaySerializer? {
    guard let displayID = window.display else { return nil }

    return displays.first { $0.id == displayID }
  }

  /// Return the space that owns a window.
  private func space(containing window: WindowSerializer) -> SpaceSerializer? {
    guard let spaceIndex = window.space else { return nil }

    return spaces.first { $0.index == spaceIndex }
  }
}
