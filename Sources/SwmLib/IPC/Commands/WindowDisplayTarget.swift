import AppKit

/// Display target for moving a window.
typealias WindowDisplayTarget = CyclicTarget

extension WindowDisplayTarget {
  /// Resolve the target display from the available screens.
  func screen(from source: NSScreen, screens: [NSScreen]) -> NSScreen? {
    element(in: screens, from: screens.firstIndex { $0.uuid == source.uuid })
  }
}
