import AppKit

/// Window state returned by query commands.
struct WindowSerializer: Encodable, Equatable {
  /// JSON keys used for window query output.
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
    case canMove = "can-move"
    case canResize = "can-resize"
    case hasFocus = "has-focus"
    case hasAXReference = "has-ax-reference"
    case isNativeFullscreen = "is-native-fullscreen"
    case isVisible = "is-visible"
    case isMinimized = "is-minimized"
  }

  /// Snapshot all manageable windows.
  static func all(snapshot: QuerySnapshot) -> [WindowSerializer] {
    snapshot.windows.map { window in
      let spaceIDs = snapshot.spaceIDsByWindowID[window.id] ?? []
      let spaceIndex = spaceIDs.lazy.compactMap { snapshot.spaceIndexByID[$0] }.first

      return WindowSerializer(
        window: window,
        info: snapshot.windowInfoByID[window.id],
        screens: snapshot.screens,
        spaceIndex: spaceIndex,
        knownSpaceIDs: spaceIDs,
        nativeFullscreen: spaceIDs.first.map(snapshot.nativeFullscreenSpaceIDs.contains)
      )
    }
  }

  /// Core Graphics window ID.
  let id: CGWindowID

  /// Owning process ID when available.
  let pid: pid_t?

  /// Owning application name when available.
  let app: String?

  /// Window title when available.
  let title: String?

  /// Window frame from accessibility data when available.
  let frame: FrameSerializer?

  /// Accessibility role when available.
  let role: String?

  /// Accessibility subrole when available.
  let subrole: String?

  /// Core Graphics display ID for the display containing most of the window.
  let display: UInt32?

  /// Zero-based space index containing the window.
  let space: Int?

  /// Core Graphics window layer when available.
  let layer: Int?

  /// Whether the window's position can be changed through accessibility.
  let canMove: Bool?

  /// Whether the window's size can be changed through accessibility.
  let canResize: Bool?

  /// Whether the window is the main accessibility window.
  let hasFocus: Bool?

  /// Whether the window has an accessibility element reference.
  let hasAXReference: Bool

  /// Whether the window is on a native fullscreen space.
  let isNativeFullscreen: Bool

  /// Whether Core Graphics reports the window as onscreen.
  let isVisible: Bool

  /// Whether accessibility reports the window as minimized.
  let isMinimized: Bool

  /// Create query output from explicit window fields.
  init(
    id: CGWindowID,
    pid: pid_t?,
    app: String?,
    title: String?,
    frame: FrameSerializer?,
    role: String?,
    subrole: String?,
    display: UInt32?,
    space: Int?,
    layer: Int?,
    canMove: Bool?,
    canResize: Bool?,
    hasFocus: Bool?,
    hasAXReference: Bool,
    isNativeFullscreen: Bool,
    isVisible: Bool,
    isMinimized: Bool,
  ) {
    self.id = id
    self.pid = pid
    self.app = app
    self.title = title
    self.frame = frame
    self.role = role
    self.subrole = subrole
    self.display = display
    self.space = space
    self.layer = layer
    self.canMove = canMove
    self.canResize = canResize
    self.hasFocus = hasFocus
    self.hasAXReference = hasAXReference
    self.isNativeFullscreen = isNativeFullscreen
    self.isVisible = isVisible
    self.isMinimized = isMinimized
  }

  /// Create query output by combining window, accessibility, and Core Graphics metadata.
  init(
    window: Window,
    info: [String: Any]?,
    screens: [NSScreen] = NSScreen.screens,
    spaceIndex: Int? = nil,
    knownSpaceIDs: [UInt64]? = nil,
    nativeFullscreen: Bool? = nil
  ) {
    let element = window.element
    let frame = element.flatMap { AccessibilityClient.shared.frame(for: $0) }
    let spaceIDs = knownSpaceIDs ?? WindowServerClient.shared.spaceIDs(containing: window.id)

    id = window.id
    pid =
      window.application?.processID
      ?? element.flatMap { AccessibilityClient.shared.processID(for: $0) }
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
    self.frame = frame.map(FrameSerializer.init)
    role = element.flatMap {
      AccessibilityClient.shared.stringAttribute(
        for: $0,
        attribute: kAXRoleAttribute as String
      )
    }
    subrole = window.subrole
    let displayScreen = frame.flatMap { rect in
      screens.max { lhs, rhs in
        rect.intersection(lhs.axFrame).area < rect.intersection(rhs.axFrame).area
      }
    }
    display = displayScreen?.id
    space = spaceIndex
    layer = (info?[kCGWindowLayer as String] as? NSNumber)?.intValue
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
    isNativeFullscreen =
      nativeFullscreen ?? spaceIDs.first.map {
        WindowServerClient.shared.spaceType(for: $0) == .fullscreen
      } ?? false
    isVisible = (info?[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
    isMinimized =
      element.flatMap {
        AccessibilityClient.shared.boolAttribute(
          for: $0,
          attribute: kAXMinimizedAttribute as String
        )
      } ?? false
  }

  /// Encode window state using stable query output keys.
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
    try container.encodeNilOrValue(canMove, forKey: .canMove)
    try container.encodeNilOrValue(canResize, forKey: .canResize)
    try container.encodeNilOrValue(hasFocus, forKey: .hasFocus)
    try container.encode(hasAXReference, forKey: .hasAXReference)
    try container.encodeNilOrValue(isNativeFullscreen, forKey: .isNativeFullscreen)
    try container.encodeNilOrValue(isVisible, forKey: .isVisible)
    try container.encodeNilOrValue(isMinimized, forKey: .isMinimized)
  }
}

/// Helpers for looking up raw Core Graphics window metadata.
extension [[String: Any]] {
  /// Index Core Graphics metadata by window ID for constant-time lookup.
  func keyedByWindowID() -> [CGWindowID: [String: Any]] {
    reduce(into: [:]) { result, info in
      guard let windowID = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value else {
        return
      }

      result[windowID] = info
    }
  }
}
