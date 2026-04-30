import ArgumentParser

struct QueryArguments: ParsableArguments {
  @Flag(help: "Return display information as JSON.")
  var displays = false

  @Flag(help: "Return window information as JSON.")
  var windows = false

  @Flag(help: "Return space information as JSON.")
  var spaces = false

  func selectedCommand() throws -> String {
    let selected = [
      (displays, "--displays"),
      (windows, "--windows"),
      (spaces, "--spaces"),
    ].filter(\.0)

    guard selected.count == 1 else {
      throw ValidationError("exactly one query flag is required")
    }

    return selected[0].1
  }

  static func makeRequest(arguments: [String]) throws -> IPCRequest {
    let supportedFlags = Set(["--displays", "--windows", "--spaces"])
    if let unsupported = arguments.first(where: { !supportedFlags.contains($0) }) {
      throw ValidationError(
        "unsupported query argument: \(unsupported); use --displays, --windows, or --spaces"
      )
    }

    let query = try QueryArguments.parse(arguments)
    return try IPCRequest(domain: .query, command: query.selectedCommand(), args: [])
  }
}
