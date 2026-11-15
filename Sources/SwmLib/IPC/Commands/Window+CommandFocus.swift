extension Window {
  func focusOrThrow() throws {
    guard focus() else {
      throw IPCCommandError.internalError("could not focus window: \(id)")
    }
  }
}
