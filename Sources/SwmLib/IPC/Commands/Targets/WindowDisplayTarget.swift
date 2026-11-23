import AppKit

typealias WindowDisplayTarget = CyclicTarget

extension WindowDisplayTarget {
  func screen(from source: NSScreen, screens: [NSScreen]) -> NSScreen? {
    element(in: screens, from: screens.firstIndex { $0.uuid == source.uuid })
  }
}
