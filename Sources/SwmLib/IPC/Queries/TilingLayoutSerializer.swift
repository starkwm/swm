import CoreGraphics

/// Logical tiling state for one Space and display, independent of parked AX coordinates.
struct TilingLayoutSerializer: Encodable {
  enum CodingKeys: String, CodingKey {
    case spaceID = "space-id"
    case displayID = "display-id"
    case layout
    case isVisible = "is-visible"
    case viewportOffset = "viewport-offset"
    case constraint
    case columns
  }

  let spaceID: UInt64
  let displayID: String
  let layout: String
  let isVisible: Bool
  let viewportOffset: CGFloat?
  let constraint: String?
  let columns: [ScrollingColumnSerializer]
}

struct ScrollingColumnSerializer: Encodable {
  enum CodingKeys: String, CodingKey {
    case window
    case width
    case isOmitted = "is-omitted"
    case isParked = "is-parked"
    case frame
  }

  let window: CGWindowID
  let width: CGFloat
  let isOmitted: Bool
  let isParked: Bool
  let frame: FrameSerializer?
}
