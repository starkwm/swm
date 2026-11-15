import CoreGraphics

enum ScreenGeometry {
  static func accessibilityFrame(_ frame: CGRect, primaryFrame: CGRect) -> CGRect {
    CGRect(
      x: frame.origin.x,
      y: primaryFrame.maxY - frame.maxY,
      width: frame.width,
      height: frame.height
    )
  }

  static func visibleFrame(
    _ visibleFrame: CGRect,
    in frame: CGRect,
    hiddenDockEdge: DockEdge?
  ) -> CGRect {
    var visible = visibleFrame
    switch hiddenDockEdge {
    case .bottom:
      visible.size.height = visible.maxY - frame.minY
      visible.origin.y = frame.minY
    case .left:
      visible.size.width = visible.maxX - frame.minX
      visible.origin.x = frame.minX
    case .right:
      visible.size.width = frame.maxX - visible.minX
    case nil:
      break
    }
    return visible
  }
}
