import CoreGraphics
import Testing

@testable import SwmLib

@Suite("WindowFrameMutation")
struct WindowFrameMutationTests {
  private let currentFrame = CGRect(x: 10, y: 20, width: 300, height: 200)
  private let targetFrame = CGRect(x: 40, y: 50, width: 500, height: 400)

  @Test("apply: resizes before moving")
  func applyResizesBeforeMoving() {
    var operations = [String]()

    let result = WindowFrameMutation.apply(
      from: currentFrame,
      to: targetFrame,
      resize: { _ in
        operations.append("resize")
        return true
      },
      move: { _ in
        operations.append("move")
        return true
      }
    )

    #expect(result == .success)
    #expect(operations == ["resize", "move"])
  }

  @Test("apply: does not move after resize failure")
  func applyDoesNotMoveAfterResizeFailure() {
    var moved = false

    let result = WindowFrameMutation.apply(
      from: currentFrame,
      to: targetFrame,
      resize: { _ in false },
      move: { _ in
        moved = true
        return true
      }
    )

    #expect(result == .resizeFailed)
    #expect(moved == false)
  }

  @Test("apply: restores size after move failure")
  func applyRestoresSizeAfterMoveFailure() {
    var sizes = [CGSize]()

    let result = WindowFrameMutation.apply(
      from: currentFrame,
      to: targetFrame,
      resize: { size in
        sizes.append(size)
        return true
      },
      move: { _ in false }
    )

    #expect(result == .moveFailed)
    #expect(sizes == [targetFrame.size, currentFrame.size])
  }

  @Test("apply: reports failed rollback")
  func applyReportsFailedRollback() {
    var resizeAttempts = 0

    let result = WindowFrameMutation.apply(
      from: currentFrame,
      to: targetFrame,
      resize: { _ in
        resizeAttempts += 1
        return resizeAttempts == 1
      },
      move: { _ in false }
    )

    #expect(result == .moveFailedAndRollbackFailed)
  }

  @Test("apply: skips unchanged frame")
  func applySkipsUnchangedFrame() {
    var mutated = false

    let result = WindowFrameMutation.apply(
      from: currentFrame,
      to: currentFrame,
      resize: { _ in
        mutated = true
        return true
      },
      move: { _ in
        mutated = true
        return true
      }
    )

    #expect(result == .success)
    #expect(mutated == false)
  }
  @Test(
    "growing animation frames move first and restore position if resizing fails",
    arguments: [true, false]
  )
  func growingFramesMoveFirst(resizeSucceeds: Bool) {
    var operations = [String]()
    let result = WindowFrameMutation.apply(
      from: currentFrame,
      to: targetFrame,
      moveBeforeResizeWhenGrowing: true,
      resize: { _ in
        operations.append("resize")
        return resizeSucceeds
      },
      move: { point in
        operations.append(point == targetFrame.origin ? "move" : "rollback")
        return true
      }
    )
    #expect(result == (resizeSucceeds ? .success : .resizeFailed))
    #expect(operations == (resizeSucceeds ? ["move", "resize"] : ["move", "resize", "rollback"]))
  }

  @Test("growing animation reports a failed position rollback")
  func growingRollbackFailure() {
    var moves = 0
    let result = WindowFrameMutation.apply(
      from: currentFrame,
      to: targetFrame,
      moveBeforeResizeWhenGrowing: true,
      resize: { _ in false },
      move: { _ in
        moves += 1
        return moves == 1
      }
    )
    #expect(result == .resizeFailedAndRollbackFailed)
  }

  @Test("shrinking animation frames retain resize-before-move ordering")
  func shrinkingFramesResizeFirst() {
    var operations = [String]()
    let result = WindowFrameMutation.apply(
      from: targetFrame,
      to: currentFrame,
      moveBeforeResizeWhenGrowing: true,
      resize: { _ in
        operations.append("resize")
        return true
      },
      move: { _ in
        operations.append("move")
        return true
      }
    )
    #expect(result == .success)
    #expect(operations == ["resize", "move"])
  }

}
