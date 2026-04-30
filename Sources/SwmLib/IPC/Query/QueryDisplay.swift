import AppKit

struct QueryDisplay: Encodable, Equatable {
  let id: String?
  let uuid: String?
  let index: Int
  let frame: QueryFrame
  let spaces: [UInt64]
  let hasFocus: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case uuid
    case index
    case frame
    case spaces
    case hasFocus = "has-focus"
  }

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

extension QueryDisplay {
  static func all() -> [QueryDisplay] {
    let displaySpaces = WindowServerClient.shared.displaySpaces(connectionID: Space.connection)
    let focusedSpace = Space.active().id

    return NSScreen.screens.enumerated().map { index, screen in
      let spaces = displaySpaces.first { $0.id == screen.id }?.spaces ?? []

      return QueryDisplay(
        id: screen.id,
        uuid: screen.id,
        index: index,
        frame: QueryFrame(screen.frame),
        spaces: spaces,
        hasFocus: spaces.contains(focusedSpace)
      )
    }
  }
}
