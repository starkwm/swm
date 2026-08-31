import ArgumentParser
import Darwin
import SwmLib

/// A typed command translated to the existing daemon IPC protocol.
protocol IPCCommand: ParsableCommand {
  static var domain: CommandDomain { get }
  static var command: String { get }

  var arguments: [String] { get }
}

extension IPCCommand {
  var arguments: [String] { [] }

  mutating func run() throws {
    let result = Client.send(
      domain: Self.domain,
      args: [Self.command] + arguments
    )

    if let outputMessage = result.outputMessage {
      let stream = result.ok ? stdout : stderr
      fputs("\(outputMessage)\n", stream)
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
}

protocol SignalIPCCommand: IPCCommand {}

extension SignalIPCCommand {
  static var domain: CommandDomain { .signal }
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
