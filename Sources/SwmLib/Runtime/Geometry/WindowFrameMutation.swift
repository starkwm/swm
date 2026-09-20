import CoreGraphics

/// Applies a frame change with best-effort rollback for partial failures.
enum WindowFrameMutation {
  /// Optionally move before growing, rolling back the first component if the second fails.
  static func apply(
    from currentFrame: CGRect,
    to targetFrame: CGRect,
    moveBeforeResizeWhenGrowing: Bool = false,
    resize: (CGSize) -> Bool,
    move: (CGPoint) -> Bool
  ) -> WindowFrameMutationResult {
    let needsResize = targetFrame.size != currentFrame.size
    let needsMove = targetFrame.origin != currentFrame.origin

    let growing = targetFrame.width > currentFrame.width || targetFrame.height > currentFrame.height
    if moveBeforeResizeWhenGrowing, growing, needsMove, needsResize {
      guard move(targetFrame.origin) else { return .moveFailed }
      guard resize(targetFrame.size) else {
        return move(currentFrame.origin) ? .resizeFailed : .resizeFailedAndRollbackFailed
      }
      return .success
    }

    if needsResize, !resize(targetFrame.size) {
      return .resizeFailed
    }

    guard !needsMove || move(targetFrame.origin) else {
      guard needsResize else { return .moveFailed }
      return resize(currentFrame.size) ? .moveFailed : .moveFailedAndRollbackFailed
    }

    return .success
  }
}

/// Result of applying a window frame through separate accessibility mutations.
enum WindowFrameMutationResult: Equatable {
  /// Requested size and position changes completed.
  case success

  /// Resizing failed with no remaining partial position change.
  case resizeFailed

  /// Resizing and the best-effort position rollback both failed.
  case resizeFailedAndRollbackFailed

  /// Moving failed with no remaining partial size change.
  case moveFailed

  /// Moving and the best-effort size rollback both failed.
  case moveFailedAndRollbackFailed
}
