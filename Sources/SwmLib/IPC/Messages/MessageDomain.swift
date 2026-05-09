import ArgumentParser

/// Top-level IPC command namespaces.
public enum MessageDomain: String, Codable, ExpressibleByArgument, Sendable {
  case config, display, space, window, query
}
