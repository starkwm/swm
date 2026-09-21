import CoreGraphics

/// Converts AppKit's upward Y axis to Accessibility's downward Y axis.
enum ScreenGeometry {
  static func accessibilityFrame(_ frame: CGRect, primaryFrame: CGRect) -> CGRect {
    CGRect(
      x: frame.origin.x,
      y: primaryFrame.maxY - frame.maxY,
      width: frame.width,
      height: frame.height
    )
  }
}
