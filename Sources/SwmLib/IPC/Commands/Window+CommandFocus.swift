extension Window {
  /// Focus the window, or throw the IPC error reported when focusing fails.
  func focusOrThrow() throws {
    guard focus() else {
      throw IPCCommandError.internalError("could not focus window: \(id)")
    }
  }
}
