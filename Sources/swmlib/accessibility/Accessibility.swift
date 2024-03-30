import Cocoa

public enum Accessibility {
  public static func askForAccessibilityIfNeeded() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary?
    return AXIsProcessTrustedWithOptions(options)
  }
}
