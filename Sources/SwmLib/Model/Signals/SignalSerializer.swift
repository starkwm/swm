/// Serialized signal state returned by `signal --list`.
struct SignalSerializer: Encodable, Equatable {
  enum CodingKeys: String, CodingKey {
    case index
    case label
    case app
    case title
    case active
    case event
    case action
  }

  private static func filterDescription(_ filter: SignalTextFilter) -> String {
    filter.inverted ? "!\(filter.pattern)" : filter.pattern
  }

  let index: Int
  let label: String?
  let app: String?
  let title: String?
  let active: Bool?
  let event: String
  let action: String

  init(indexedSignal: IndexedSignal) {
    index = indexedSignal.index
    label = indexedSignal.signal.label
    app = indexedSignal.signal.appFilter.map(Self.filterDescription)
    title = indexedSignal.signal.titleFilter.map(Self.filterDescription)
    active = indexedSignal.signal.active
    event = indexedSignal.signal.event.rawValue
    action = indexedSignal.signal.action
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(index, forKey: .index)
    try container.encodeNilOrValue(label, forKey: .label)
    try container.encodeNilOrValue(app, forKey: .app)
    try container.encodeNilOrValue(title, forKey: .title)
    try container.encodeNilOrValue(active, forKey: .active)
    try container.encode(event, forKey: .event)
    try container.encode(action, forKey: .action)
  }
}
