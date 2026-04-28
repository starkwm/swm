import ApplicationServices

final class EventManager {
  static let shared = EventManager()

  private init() {}

  func post(_ event: RuntimeEvent) {
    // TODO: Wire runtime event dispatch once window/config command handling exists.
  }

  func post(
    windowIdentifierEvent event: WindowIdentifierEvent,
    withWindowElement element: AXUIElement
  ) {
    // TODO: Resolve AX window identifier events once runtime event dispatch exists.
  }

  func post(windowCreatedWithElement element: AXUIElement) {
    // TODO: Resolve AX window creation events once runtime event dispatch exists.
  }
}
