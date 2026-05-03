enum RuntimeEvent: Sendable {
  case application(ApplicationEvent)
  case window(WindowEvent)
  case space(SpaceEvent)

  var type: EventType {
    switch self {
    case .application(let event):
      event.type
    case .window(let event):
      event.type
    case .space(let event):
      event.type
    }
  }
}
