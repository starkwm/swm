/// Top-level runtime event routed by `EventManager`.
enum RuntimeEvent: Sendable {
  /// Application lifecycle event.
  case application(ApplicationEvent)

  /// Window lifecycle event.
  case window(WindowEvent)

  /// Space lifecycle event.
  case space(SpaceEvent)

  /// Display lifecycle event.
  case display(DisplayEvent)

  /// Flat event type for this runtime event.
  var type: EventType {
    switch self {
    case .application(let event):
      event.type
    case .window(let event):
      event.type
    case .space(let event):
      event.type
    case .display(let event):
      event.type
    }
  }
}
