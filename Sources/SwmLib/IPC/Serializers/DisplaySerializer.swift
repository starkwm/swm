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
    let displaySpaces = WindowServerClient.shared.displaySpaces(connectionID: Space.connection)
    let indexedSpaces = Space.all().enumerated().map { (index: $0.offset, id: $0.element.id) }
    let focusedSpace = Space.active().id

    return displaySpaces.enumerated().map { index, display in
      let screen = NSScreen.screen(for: display.id) ?? NSScreen.screens[safe: index]
      let spaceIDs = display.spaces
      let spaces = indexedSpaces.compactMap { spaceIDs.contains($0.id) ? $0.index : nil }
      let currentSpace = WindowServerClient.shared.currentSpace(
        connectionID: Space.connection,
        screenID: display.id
      )

      return DisplaySerializer(
        id: display.id,
        uuid: display.id,
        index: index,
        frame: FrameSerializer(screen?.frame ?? .zero),
        spaces: spaces,
        hasFocus: currentSpace == focusedSpace
      )
    }
  }

  let id: String?
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

extension [NSScreen] {
  fileprivate subscript(safe index: Int) -> NSScreen? {
    indices.contains(index) ? self[index] : nil
  }
}
