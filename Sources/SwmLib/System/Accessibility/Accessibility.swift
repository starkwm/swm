import Cocoa

public enum Accessibility {
  public static func askForAccessibilityIfNeeded() -> Bool {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary?
    return AXIsProcessTrustedWithOptions(options)
  }
}
