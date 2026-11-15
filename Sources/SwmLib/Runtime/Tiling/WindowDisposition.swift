import CoreGraphics

enum WindowDisposition: Equatable {
  case tiled

  case floating(WindowExclusionReason)

  case excluded(WindowExclusionReason)

  case pending
}

enum WindowExclusionReason: Equatable {
  case multipleSpaces

  case nativeFullscreen

  case unsupportedSubrole

  case notMovable

  case notResizable
}

struct TilingWindowSnapshot: Equatable {
  let id: CGWindowID

  let displayID: String?

  let subrole: String?

  let isMinimized: Bool

  let isMovable: Bool

  let isResizable: Bool

  var hasUnavailableFacts = false

  var app: String? = nil
  var title: String? = nil
  var bundleID: String? = nil
}

enum WindowEligibilityPolicy {
  static func disposition(
    for window: TilingWindowSnapshot,
    topology: SpaceTopology
  ) -> WindowDisposition {
    guard !window.hasUnavailableFacts else { return .pending }
    guard window.subrole == "AXStandardWindow" else {
      return .excluded(.unsupportedSubrole)
    }
    guard window.isMovable else { return .excluded(.notMovable) }
    guard window.isResizable else { return .excluded(.notResizable) }
    guard window.displayID != nil else { return .pending }

    let membership = topology.spaceIDsByWindowID[window.id] ?? []
    let normalSpaceIDs = topology.normalSpaceIDs(for: window.id)

    if normalSpaceIDs.count > 1 {
      return .floating(.multipleSpaces)
    }
    if normalSpaceIDs.count == 1 {
      return .tiled
    }
    if membership.contains(where: { topology.spacesByID[$0]?.type == .fullscreen }) {
      return .excluded(.nativeFullscreen)
    }

    return .pending
  }
}
