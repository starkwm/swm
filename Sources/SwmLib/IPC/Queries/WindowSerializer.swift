import AppKit

struct WindowSerializer: Encodable, Equatable {
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
    case tiling
    case tilingReason = "tiling-reason"
  }

  @MainActor
  static func all(snapshot: QuerySnapshot) -> [WindowSerializer] {
    snapshot.windows.map { window in
      let spaceIDs = snapshot.spaceIDsByWindowID[window.id] ?? []
      let spaceIndex = spaceIDs.lazy.compactMap { snapshot.spaceIndexByID[$0] }.first

      return WindowSerializer(
        window: window,
        focusedWindowID: snapshot.focusedWindowID,
        info: snapshot.windowInfoByID[window.id],
        screens: snapshot.screens,
        spaceIndex: spaceIndex,
        nativeFullscreen: spaceIDs.first.map(snapshot.nativeFullscreenSpaceIDs.contains) ?? false,
        tiling: snapshot.tiling?.tilingStatus(for: window.id)
      )
    }
  }

  let id: CGWindowID

  let pid: pid_t?

  let app: String?

  let title: String?

  let frame: FrameSerializer?

  let role: String?

  let subrole: String?

  let display: UInt32?

  let space: Int?

  let layer: Int?

  let canMove: Bool?

  let canResize: Bool?

  let hasFocus: Bool?

  let hasAXReference: Bool

  let isNativeFullscreen: Bool

  let isVisible: Bool

  let isMinimized: Bool

  let tiling: WindowDisposition?

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
    try container.encodeNilOrValue(tiling?.state, forKey: .tiling)
    try container.encodeNilOrValue(tiling?.reason?.rawValue, forKey: .tilingReason)
  }
}

extension WindowSerializer {
  @MainActor
  init(
    window: Window,
    focusedWindowID: CGWindowID?,
    info: [String: Any]?,
    screens: [NSScreen],
    spaceIndex: Int?,
    nativeFullscreen: Bool,
    tiling: WindowDisposition?
  ) {
    let element = window.element
    let frame = window.frame()

    id = window.id
    pid =
      window.application?.processID
      ?? element.flatMap { AccessibilityClient.shared.processID(for: $0) }
    app =
      window.application?.name
      ?? (info?[kCGWindowOwnerName as String] as? String)
    title = window.accessibilityTitle ?? (info?[kCGWindowName as String] as? String)
    self.frame = frame.map(FrameSerializer.init)
    role = element.flatMap {
      AccessibilityClient.shared.stringAttribute(
        for: $0,
        attribute: kAXRoleAttribute as String
      )
    }
    subrole = window.subrole
    let displayScreen = frame.flatMap { rect in
      screens.largestIntersection(with: rect, frame: \.axFrame)
    }
    display = displayScreen?.id
    space = spaceIndex
    layer = (info?[kCGWindowLayer as String] as? NSNumber)?.intValue
    canMove = element.map { _ in window.isMovable }
    canResize = element.map { _ in window.isResizable }
    hasFocus = focusedWindowID.map { $0 == window.id }
    hasAXReference = element != nil
    isNativeFullscreen = nativeFullscreen
    isVisible = (info?[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
    isMinimized = window.isMinimized
    self.tiling = tiling
  }
}
