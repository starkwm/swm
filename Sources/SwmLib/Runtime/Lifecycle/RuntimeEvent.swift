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
}
