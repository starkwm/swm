/// Top-level IPC command namespaces.
public enum CommandDomain: String, Codable, Sendable {
  case config, display, space, window, query, signal
}
