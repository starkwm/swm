struct SpaceResultSerializer: Encodable {
  let id: UInt64
  let paddingEnabled: Bool
  let gapEnabled: Bool
  let padding: SpacePaddingSerializer
  let gap: Int

  enum CodingKeys: String, CodingKey {
    case id
    case paddingEnabled = "padding-enabled"
    case gapEnabled = "gap-enabled"
    case padding
    case gap
  }
}
