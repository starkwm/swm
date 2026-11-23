import ArgumentParser
import Darwin
import Foundation
import SwmLib

protocol DaemonCommand: ParsableCommand {
  var ipcCommand: IPCCommand { get }

  func formatted(_ message: String, forTerminal: Bool) -> String
}

extension DaemonCommand {
  func formatted(_ message: String, forTerminal: Bool) -> String { message }

  mutating func run() throws {
    try run(send: Client.send, output: stdout, errors: stderr)
  }

  mutating func run(
    send: (IPCCommand) -> Client.SendResult,
    output: UnsafeMutablePointer<FILE>,
    errors: UnsafeMutablePointer<FILE>
  ) throws {
    let result = send(ipcCommand)
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

protocol QueryDaemonCommand: DaemonCommand {}

extension QueryDaemonCommand {
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

enum MasterPlacementName: String, CaseIterable, ExpressibleByArgument {
  case left, right, top, bottom, next, prev

  var change: MasterPlacementChange {
    switch self {
    case .left: .set(.left)
    case .right: .set(.right)
    case .top: .set(.top)
    case .bottom: .set(.bottom)
    case .next: .cycle(.next)
    case .prev: .cycle(.prev)
    }
  }
}

enum ToggleState: String, CaseIterable, ExpressibleByArgument {
  case on, off

  var isEnabled: Bool { self == .on }
}
