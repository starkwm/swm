import ArgumentParser

struct QueryArguments: ParsableArguments {
  private static let commandFlags = ["--displays", "--windows", "--spaces"]

  @Flag(help: "Return display information as JSON.")
  var displays = false

  @Flag(help: "Return window information as JSON.")
  var windows = false

  @Flag(help: "Return space information as JSON.")
  var spaces = false

  @Option(parsing: .upToNextOption, help: "Select focused display or display index.")
  var display: [String] = []

  @Option(parsing: .upToNextOption, help: "Select focused space or space index.")
  var space: [String] = []

  @Option(parsing: .upToNextOption, help: "Select focused window or window id.")
  var window: [String] = []

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
    let selection = try QuerySelection.parse(arguments: arguments)
    let command = try selectedCommand(in: arguments, selection: selection)

    return IPCRequest(domain: .query, command: command, args: selection.requestArguments)
  }

  private static func selectedCommand(
    in arguments: [String],
    selection: QuerySelection
  ) throws -> String {
    let query = try QueryArguments.parse(
      arguments.filter {
        commandFlags.contains($0)
      }
    )

    do {
      return try query.selectedCommand()
    } catch {
      if let command = selection.defaultCommand {
        return command
      }

      throw error
    }
  }
}
