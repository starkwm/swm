import CoreGraphics

/// Applies a frame change with best-effort rollback for partial failures.
enum WindowFrameMutation {
  /// Resize then move a window, restoring its original size if moving fails.
  static func apply(
    from currentFrame: CGRect,
    to targetFrame: CGRect,
    resize: (CGSize) -> Bool,
    move: (CGPoint) -> Bool
  ) -> WindowFrameMutationResult {
    let needsResize = targetFrame.size != currentFrame.size
    let needsMove = targetFrame.origin != currentFrame.origin

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

  /// Resizing failed before any position change was attempted.
  case resizeFailed

  /// Moving failed with no remaining partial size change.
  case moveFailed

  /// Moving and the best-effort size rollback both failed.
  case moveFailedAndRollbackFailed
}
