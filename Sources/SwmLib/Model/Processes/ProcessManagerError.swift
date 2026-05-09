/// Errors raised while starting or accessing process observation.
public enum ProcessManagerError: Error, CustomStringConvertible {
  /// Process observation could not be started or accessed.
  case accessFailed(String)

  /// Human-readable process manager failure description.
  public var description: String {
    switch self {
    case .accessFailed(let message):
      return message
    }
  }
}
