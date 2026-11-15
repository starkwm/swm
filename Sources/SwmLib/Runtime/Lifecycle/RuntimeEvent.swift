enum RuntimeEvent: Sendable {
  case application(ApplicationEvent)

  case window(WindowEvent)

  case space(SpaceEvent)

  case display(DisplayEvent)
}
