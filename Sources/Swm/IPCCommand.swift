import ArgumentParser
import Darwin
import Foundation
import SwmLib

protocol IPCCommand: ParsableCommand {
  static var domain: CommandDomain { get }
  static var command: String { get }

  var requestDomain: CommandDomain { get }
  var arguments: [String] { get }

  var commandArguments: [String] { get }

  func formatted(_ message: String, forTerminal: Bool) -> String
}

extension IPCCommand {
  var requestDomain: CommandDomain { Self.domain }

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
    let result = send(requestDomain, commandArguments)
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

protocol ScopedConfigIPCCommand: ConfigIPCCommand {
  var scope: ConfigScopeOptions { get }
  var settingArguments: [String] { get }
}

extension ScopedConfigIPCCommand {
  var requestDomain: CommandDomain { scope.space == nil ? .config : .space }

  var arguments: [String] { scope.arguments + settingArguments }

  var commandArguments: [String] {
    [scope.space == nil ? Self.command : "--" + Self.command] + arguments
  }
}

protocol QueryIPCCommand: IPCCommand {}

extension QueryIPCCommand {
  static var domain: CommandDomain { .query }

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

protocol DisplayIPCCommand: IPCCommand {}

extension DisplayIPCCommand {
  static var domain: CommandDomain { .display }
}

protocol WindowIPCCommand: IPCCommand {}

extension WindowIPCCommand {
  static var domain: CommandDomain { .window }
}

enum MasterPlacementName: String, CaseIterable, ExpressibleByArgument {
  case left, right, top, bottom, next, prev
}

enum ToggleState: String, CaseIterable, ExpressibleByArgument {
  case on, off
}
