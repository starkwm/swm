import AppKit

/// Serialized display state returned by query IPC commands.
struct DisplaySerializer: Encodable, Equatable {
  /// JSON keys used for display query output.
  enum CodingKeys: String, CodingKey {
    case id
    case uuid
    case index
    case frame
    case spaces
    case hasFocus = "has-focus"
  }

  /// Snapshot all displays and their associated space indexes.
  static func all() -> [DisplaySerializer] {
    let displaySpaces = Dictionary(
      uniqueKeysWithValues: WindowServerClient.shared.displaySpaces().map { ($0.id, $0.spaces) }
    )
    let indexedSpaces = SpaceManager.all()
      .enumerated()
      .map { (index: $0.offset, id: $0.element.id) }
    let focusedSpace = SpaceManager.active().id

    return NSScreen.arrangedScreens.enumerated().compactMap { index, screen in
      guard let spaces = displaySpaces[screen.uuid] else {
        return nil
      }

      return DisplaySerializer(
        id: screen.id,
        uuid: screen.uuid,
        index: index + 1,
        frame: FrameSerializer(screen.frame),
        spaces: indexedSpaces.compactMap { spaces.contains($0.id) ? $0.index : nil },
        hasFocus: WindowServerClient.shared.currentSpace(for: screen.uuid) == focusedSpace
      )
    }
  }

  /// Core Graphics display ID when available.
  let id: UInt32?

  /// Stable display UUID when available.
  let uuid: String?

  /// One-based display index in physical arrangement order.
  let index: Int

  /// Display frame in global screen coordinates.
  let frame: FrameSerializer

  /// Zero-based indexes of spaces on this display.
  let spaces: [Int]

  /// Whether this display owns the active space.
  let hasFocus: Bool

  /// Encode display state using stable query output keys.
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeNilOrValue(id, forKey: .id)
    try container.encodeNilOrValue(uuid, forKey: .uuid)
    try container.encode(index, forKey: .index)
    try container.encode(frame, forKey: .frame)
    try container.encode(spaces, forKey: .spaces)
    try container.encode(hasFocus, forKey: .hasFocus)
  }
}
