import ArgumentParser

public enum MessageDomain: String, Codable, ExpressibleByArgument, Sendable {
  case config, display, space, window, query
}
