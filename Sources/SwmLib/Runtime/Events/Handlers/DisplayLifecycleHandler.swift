struct DisplayLifecycleHandler {
  func handle(_ event: DisplayEvent) {
    switch event {
    case .changed:
      displayChanged()
    }
  }

  private func displayChanged() {
    log("display changed")
  }
}
