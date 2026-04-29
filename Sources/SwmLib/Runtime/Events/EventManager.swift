final class EventManager {
  static let shared = EventManager()

  private init() {}

  func post(_ event: RuntimeEvent) {
    // TODO: Wire runtime event dispatch once window/config command handling exists.
  }
}
