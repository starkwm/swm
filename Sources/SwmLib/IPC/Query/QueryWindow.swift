import AppKit

struct QueryWindow: Encodable, Equatable {
  let id: CGWindowID
  let pid: pid_t?
  let app: String?
  let title: String?
  let frame: QueryFrame?
  let role: String?
  let subrole: String?
  let display: String?
  let space: Int?
  let layer: Int?
  let subLayer: Int?
  let canMove: Bool?
  let canResize: Bool?
  let hasFocus: Bool?
  let hasAXReference: Bool
  let isNativeFullscreen: Bool?
  let isVisible: Bool?
  let isMinimized: Bool?
  let isFloating: Bool?

  enum CodingKeys: String, CodingKey {
    case id
    case pid
    case app
    case title
    case frame
    case role
    case subrole
    case display
    case space
    case layer
    case subLayer = "sub-layer"
    case canMove = "can-move"
    case canResize = "can-resize"
    case hasFocus = "has-focus"
    case hasAXReference = "has-ax-reference"
    case isNativeFullscreen = "is-native-fullscreen"
    case isVisible = "is-visible"
    case isMinimized = "is-minimized"
    case isFloating = "is-floating"
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encodeNilOrValue(pid, forKey: .pid)
    try container.encodeNilOrValue(app, forKey: .app)
    try container.encodeNilOrValue(title, forKey: .title)
    try container.encodeNilOrValue(frame, forKey: .frame)
    try container.encodeNilOrValue(role, forKey: .role)
    try container.encodeNilOrValue(subrole, forKey: .subrole)
    try container.encodeNilOrValue(display, forKey: .display)
    try container.encodeNilOrValue(space, forKey: .space)
    try container.encodeNilOrValue(layer, forKey: .layer)
    try container.encodeNilOrValue(subLayer, forKey: .subLayer)
    try container.encodeNilOrValue(canMove, forKey: .canMove)
    try container.encodeNilOrValue(canResize, forKey: .canResize)
    try container.encodeNilOrValue(hasFocus, forKey: .hasFocus)
    try container.encode(hasAXReference, forKey: .hasAXReference)
    try container.encodeNilOrValue(isNativeFullscreen, forKey: .isNativeFullscreen)
    try container.encodeNilOrValue(isVisible, forKey: .isVisible)
    try container.encodeNilOrValue(isMinimized, forKey: .isMinimized)
    try container.encodeNilOrValue(isFloating, forKey: .isFloating)
  }
}

extension QueryWindow {
  static func all() -> [QueryWindow] {
    let windowInfo = windowInfo()
    let screens = NSScreen.screens
    let displaySpaces = WindowServerClient.shared.displaySpaces(connectionID: Space.connection)
    let spaces = Space.all()

    return WindowManager.shared.allWindows().map { window in
      QueryWindow(
        window: window,
        info: windowInfo.info(for: window.id),
        screens: screens,
        displaySpaces: displaySpaces,
        spaceIndex: spaces.spaceIndex(containing: window.id)
      )
    }
  }

  static func windowInfo() -> [[String: Any]] {
    CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
  }

  init(
    window: Window,
    info: [String: Any]?,
    screens: [NSScreen] = NSScreen.screens,
    displaySpaces: [WindowServerDisplaySpaces] = WindowServerClient.shared.displaySpaces(
      connectionID: Space.connection
    ),
    spaceIndex: Int? = nil
  ) {
    let element = window.element
    let frame = element.flatMap { AccessibilityClient.shared.frame(for: $0) }
    let spaceIDs = WindowServerClient.shared.spaceIDs(
      containing: window.id,
      connectionID: Space.connection
    )

    id = window.id
    pid = window.application?.processID ?? element.flatMap { Window.pid(for: $0) }
    app =
      window.application?.name
      ?? (info?[kCGWindowOwnerName as String] as? String)
    title =
      element.flatMap {
        AccessibilityClient.shared.stringAttribute(
          for: $0,
          attribute: kAXTitleAttribute as String
        )
      } ?? (info?[kCGWindowName as String] as? String)
    self.frame = frame.map(QueryFrame.init)
    role = element.flatMap {
      AccessibilityClient.shared.stringAttribute(
        for: $0,
        attribute: kAXRoleAttribute as String
      )
    }
    subrole = window.subrole
    let displayIndex = frame.flatMap { rect in
      screens.indices.max { a, b in
        rect.intersection(screens[a].frame).area < rect.intersection(screens[b].frame).area
      }
    }
    display = displayIndex.flatMap { index in
      displaySpaces.first { $0.id == screens[index].id }?.id
        ?? displaySpaces[safe: index]?.id
        ?? screens[index].id
    }
    space = spaceIndex
    layer = (info?[kCGWindowLayer as String] as? NSNumber)?.intValue
    subLayer = nil
    canMove = element.map {
      AccessibilityClient.shared.isAttributeSettable(
        kAXPositionAttribute as String,
        for: $0
      )
    }
    canResize = element.map {
      AccessibilityClient.shared.isAttributeSettable(kAXSizeAttribute as String, for: $0)
    }
    hasFocus = element.map { AccessibilityClient.shared.isMainWindow($0) }
    hasAXReference = element != nil
    isNativeFullscreen = spaceIDs.first.map {
      WindowServerClient.shared.spaceType(connectionID: Space.connection, spaceID: $0)
        == .fullscreen
    }
    isVisible = (info?[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue
    isMinimized = element.flatMap {
      AccessibilityClient.shared.boolAttribute(for: $0, attribute: kAXMinimizedAttribute as String)
    }
    isFloating = layer.map { $0 != 0 }
  }
}

extension [[String: Any]] {
  func info(for windowID: CGWindowID) -> [String: Any]? {
    first { info in
      (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value == windowID
    }
  }
}

extension [Space] {
  func spaceIndex(containing windowID: CGWindowID) -> Int? {
    let spaceIDs = WindowServerClient.shared.spaceIDs(
      containing: windowID,
      connectionID: Space.connection
    )

    guard let spaceID = spaceIDs.first else { return nil }
    return firstIndex { $0.id == spaceID }
  }
}

extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

extension CGRect {
  fileprivate var area: CGFloat {
    width * height
  }
}
