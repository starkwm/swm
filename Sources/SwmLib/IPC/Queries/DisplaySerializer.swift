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

  @MainActor
  static func all(snapshot: QuerySnapshot) -> [DisplaySerializer] {
    let displaySpaces = Dictionary(
      snapshot.displaySpaces.map { ($0.key.lowercased(), $0.value) },
      uniquingKeysWith: +
    )
    let indexedSpaces = snapshot.spaces
      .enumerated()
      .map { (index: $0.offset + 1, id: $0.element.id) }

    return snapshot.arrangedScreens.enumerated().map { index, screen in
      let spaces = displaySpaces[screen.uuid.lowercased()] ?? displaySpaces["main"] ?? []

      return DisplaySerializer(
        id: screen.id,
        uuid: screen.uuid,
        index: index + 1,
        frame: FrameSerializer(screen.frame),
        spaces: indexedSpaces.compactMap { spaces.contains($0.id) ? $0.index : nil },
        hasFocus: snapshot.activeSpaceID.map {
          snapshot.currentSpaceByScreenID[screen.uuid] == $0
        } ?? false
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
