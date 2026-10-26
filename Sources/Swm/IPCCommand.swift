import ArgumentParser
import Darwin
import Foundation
import SwmLib

/// A typed command translated to the existing daemon IPC protocol.
protocol IPCCommand: ParsableCommand {
  static var domain: CommandDomain { get }
  static var command: String { get }

  var arguments: [String] { get }

  /// The daemon command and its arguments.
  var commandArguments: [String] { get }

  /// Format a successful response for output to a terminal or a pipe.
  func formatted(_ message: String, forTerminal: Bool) -> String
}

extension IPCCommand {
  var arguments: [String] { [] }

  var commandArguments: [String] { [Self.command] + arguments }

  func formatted(_ message: String, forTerminal: Bool) -> String { message }

  mutating func run() throws {
    try run(send: Client.send, output: stdout, errors: stderr)
  }

  mutating func run(
    send: (CommandDomain, [String]) -> Client.SendResult,
    output: UnsafeMutablePointer<FILE>,
    errors: UnsafeMutablePointer<FILE>
  ) throws {
    let result = send(Self.domain, commandArguments)
    let message =
      result.ok
      ? formatted(result.outputMessage, forTerminal: isatty(fileno(output)) != 0)
      : result.outputMessage

    if !message.isEmpty {
      fputs("\(message)\n", result.ok ? output : errors)
    }

    if !result.ok {
      throw ExitCode.failure
    }
  }
}

protocol ConfigIPCCommand: IPCCommand {}

extension ConfigIPCCommand {
  static var domain: CommandDomain { .config }
}

protocol QueryIPCCommand: IPCCommand {}

extension QueryIPCCommand {
  static var domain: CommandDomain { .query }

  /// Indent JSON for a terminal, and keep it on one line for pipes.
  func formatted(_ message: String, forTerminal: Bool) -> String {
    guard
      forTerminal,
      let object = try? JSONSerialization.jsonObject(
        with: Data(message.utf8),
        options: .fragmentsAllowed
      ),
      let data = try? JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
      )
    else {
      return message
    }
    return String(decoding: data, as: UTF8.self)
  }
}

protocol SignalIPCCommand: IPCCommand {}

extension SignalIPCCommand {
  static var domain: CommandDomain { .signal }
}

protocol RuleIPCCommand: IPCCommand {}

extension RuleIPCCommand {
  static var domain: CommandDomain { .rule }
}

protocol SpaceIPCCommand: IPCCommand {}

extension SpaceIPCCommand {
  static var domain: CommandDomain { .space }
}

protocol WindowIPCCommand: IPCCommand {}

extension WindowIPCCommand {
  static var domain: CommandDomain { .window }
}

/// Values shared by multiple command domains.
enum LayoutName: String, CaseIterable, ExpressibleByArgument {
  case float, master, monocle, dwindle
}

/// Enable or disable a setting.
enum ToggleState: String, CaseIterable, ExpressibleByArgument {
  case on, off
}
