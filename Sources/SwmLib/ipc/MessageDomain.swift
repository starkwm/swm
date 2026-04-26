import ArgumentParser

public enum MessageDomain: String, Codable, ExpressibleByArgument {
  case config, display, space, window, query
}
