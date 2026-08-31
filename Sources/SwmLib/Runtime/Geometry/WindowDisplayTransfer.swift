import CoreGraphics

/// Calculates equivalent window placement on another display.
struct WindowDisplayTransfer: Equatable {
  let windowFrame: CGRect
  let sourceFrame: CGRect
  let targetFrame: CGRect

  /// Calculate a target frame preserving relative origin and fitting destination bounds.
  func targetWindowFrame() -> CGRect {
    let width = min(windowFrame.width, targetFrame.width)
    let height = min(windowFrame.height, targetFrame.height)
    let xProgress = progress(
      windowFrame.minX - sourceFrame.minX,
      over: sourceFrame.width - windowFrame.width
    )
    let yProgress = progress(
      windowFrame.minY - sourceFrame.minY,
      over: sourceFrame.height - windowFrame.height
    )

    let x = targetFrame.minX + xProgress * (targetFrame.width - width)
    let y = targetFrame.minY + yProgress * (targetFrame.height - height)

    return CGRect(
      x: clamp(x, lower: targetFrame.minX, upper: targetFrame.maxX - width),
      y: clamp(y, lower: targetFrame.minY, upper: targetFrame.maxY - height),
      width: width,
      height: height
    )
  }

  private func progress(_ value: CGFloat, over range: CGFloat) -> CGFloat {
    guard range > 0 else { return 0 }
    return clamp(value / range, lower: 0, upper: 1)
  }

  private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
    min(max(value, lower), upper)
  }
}
