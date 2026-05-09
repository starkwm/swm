import Cocoa

/// Helpers for checking and requesting macOS accessibility permission.
public enum Accessibility {
  /// Prompt for accessibility permission when needed and return current trust status.
  public static func askForAccessibilityIfNeeded() -> Bool {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary?
    return AXIsProcessTrustedWithOptions(options)
  }
}
