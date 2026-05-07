import AppKit

struct DisplaySerializer: Encodable, Equatable {
  enum CodingKeys: String, CodingKey {
    case id
    case uuid
    case index
    case frame
    case spaces
    case hasFocus = "has-focus"
  }

  static func all() -> [DisplaySerializer] {
    let displaySpaces = WindowServerClient.shared.displaySpaces()
    let indexedSpaces = SpaceManager.all()
      .enumerated()
      .map { (index: $0.offset, id: $0.element.id) }
    let focusedSpace = SpaceManager.active().id

    return displaySpaces.enumerated().compactMap { index, display in
      guard let screen = NSScreen.screen(for: display.id) else {
        return nil
      }

      return DisplaySerializer(
        id: screen.id,
        uuid: screen.uuid,
        index: index,
        frame: FrameSerializer(screen.frame),
        spaces: indexedSpaces.compactMap { display.spaces.contains($0.id) ? $0.index : nil },
        hasFocus: WindowServerClient.shared.currentSpace(for: screen.uuid) == focusedSpace
      )
    }
  }

  let id: UInt32?
  let uuid: String?
  let index: Int
  let frame: FrameSerializer
  let spaces: [Int]
  let hasFocus: Bool

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
