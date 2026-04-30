import AppKit

struct QueryWindow: Encodable, Equatable {
  let id: CGWindowID
  let pid: pid_t?
  let app: String?
  let title: String?
  let frame: QueryFrame?
  let role: String?
  let subrole: String?
  let rootWindow: CGWindowID?
  let display: String?
  let space: UInt64?
  let level: Int?
  let subLevel: Int?
  let layer: Int?
  let subLayer: Int?
  let opacity: Double?
  let canMove: Bool?
  let canResize: Bool?
  let hasFocus: Bool?
  let hasShadow: Bool?
  let hasParentZoom: Bool?
  let hasFullscreenZoom: Bool?
  let hasAXReference: Bool
  let isNativeFullscreen: Bool?
  let isVisible: Bool?
  let isMinimized: Bool?
  let isHidden: Bool?
  let isFloating: Bool?
  let isSticky: Bool?

  enum CodingKeys: String, CodingKey {
    case id
    case pid
    case app
    case title
    case frame
    case role
    case subrole
    case rootWindow = "root-window"
    case display
    case space
    case level
    case subLevel = "sub-level"
    case layer
    case subLayer = "sub-layer"
    case opacity
    case canMove = "can-move"
    case canResize = "can-resize"
    case hasFocus = "has-focus"
    case hasShadow = "has-shadow"
    case hasParentZoom = "has-parent-zoom"
    case hasFullscreenZoom = "has-fullscreen-zoom"
    case hasAXReference = "has-ax-reference"
    case isNativeFullscreen = "is-native-fullscreen"
    case isVisible = "is-visible"
    case isMinimized = "is-minimized"
    case isHidden = "is-hidden"
    case isFloating = "is-floating"
    case isSticky = "is-sticky"
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
    try container.encodeNilOrValue(rootWindow, forKey: .rootWindow)
    try container.encodeNilOrValue(display, forKey: .display)
    try container.encodeNilOrValue(space, forKey: .space)
    try container.encodeNilOrValue(level, forKey: .level)
    try container.encodeNilOrValue(subLevel, forKey: .subLevel)
    try container.encodeNilOrValue(layer, forKey: .layer)
    try container.encodeNilOrValue(subLayer, forKey: .subLayer)
    try container.encodeNilOrValue(opacity, forKey: .opacity)
    try container.encodeNilOrValue(canMove, forKey: .canMove)
    try container.encodeNilOrValue(canResize, forKey: .canResize)
    try container.encodeNilOrValue(hasFocus, forKey: .hasFocus)
    try container.encodeNilOrValue(hasShadow, forKey: .hasShadow)
    try container.encodeNilOrValue(hasParentZoom, forKey: .hasParentZoom)
    try container.encodeNilOrValue(hasFullscreenZoom, forKey: .hasFullscreenZoom)
    try container.encode(hasAXReference, forKey: .hasAXReference)
    try container.encodeNilOrValue(isNativeFullscreen, forKey: .isNativeFullscreen)
    try container.encodeNilOrValue(isVisible, forKey: .isVisible)
    try container.encodeNilOrValue(isMinimized, forKey: .isMinimized)
    try container.encodeNilOrValue(isHidden, forKey: .isHidden)
    try container.encodeNilOrValue(isFloating, forKey: .isFloating)
    try container.encodeNilOrValue(isSticky, forKey: .isSticky)
  }
}

extension QueryWindow {
  static func all() -> [QueryWindow] {
    let windowInfo =
      CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]]
      ?? []

    return WindowManager.shared.allWindows().map { window in
      QueryWindow(
        window: window,
        info: windowInfo.first { info in
          (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value == window.id
        }
      )
    }
  }

  init(window: Window, info: [String: Any]?) {
    let element = window.element
    let frame = element.flatMap { AccessibilityClient.shared.frame(for: $0) }
    let spaces = WindowServerClient.shared.spaceIDs(
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
    rootWindow = nil
    display = frame.flatMap { rect in
      NSScreen.screens.max { a, b in
        rect.intersection(a.frame).area < rect.intersection(b.frame).area
      }?.id
    }
    space = spaces.first
    level = nil
    subLevel = nil
    layer = (info?[kCGWindowLayer as String] as? NSNumber)?.intValue
    subLayer = nil
    opacity = (info?[kCGWindowAlpha as String] as? NSNumber)?.doubleValue
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
    hasShadow = nil
    hasParentZoom = nil
    hasFullscreenZoom = nil
    hasAXReference = element != nil
    isNativeFullscreen = spaces.first.map {
      WindowServerClient.shared.spaceType(connectionID: Space.connection, spaceID: $0)
        == .fullscreen
    }
    isVisible = (info?[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue
    isMinimized = element.flatMap {
      AccessibilityClient.shared.boolAttribute(for: $0, attribute: kAXMinimizedAttribute as String)
    }
    isHidden = nil
    isFloating = layer.map { $0 != 0 }
    isSticky = nil
  }
}

extension CGRect {
  fileprivate var area: CGFloat {
    width * height
  }
}
