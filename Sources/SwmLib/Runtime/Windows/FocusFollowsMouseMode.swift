/// Focus behavior applied when the pointer enters a managed window.
public enum FocusFollowsMouseMode: String, CaseIterable, Sendable {
  case off
  case autofocus
  case autoraise
}
