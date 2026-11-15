import CoreGraphics

enum WindowFrameMutation {
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

enum WindowFrameMutationResult: Equatable {
  case success

  case resizeFailed

  case resizeFailedAndRollbackFailed

  case moveFailed

  case moveFailedAndRollbackFailed
}
