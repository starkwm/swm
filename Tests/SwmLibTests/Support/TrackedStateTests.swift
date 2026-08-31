import Testing

@testable import SwmLib

@Suite("TrackedState")
struct TrackedStateTests {
  @Test("init: sets current and last to value")
  func initSetsCurrentAndLastToValue() {
    let state = TrackedState(current: 42)

    #expect(state.current == 42)
    #expect(state.last == 42)
  }

  @Test("init: keeps nil current and last")
  func initKeepsNilCurrentAndLast() {
    let state = TrackedState<Int>(current: nil)

    #expect(state.current == nil)
    #expect(state.last == nil)
  }

  @Test("update: keeps current and last unchanged for same value")
  func updateKeepsCurrentAndLastUnchangedForSameValue() {
    var state = TrackedState(current: 42)

    state.update(to: 42)

    #expect(state.current == 42)
    #expect(state.last == 42)
  }

  @Test("update: stores previous current as last for new value")
  func updateStoresPreviousCurrentAsLastForNewValue() {
    var state = TrackedState(current: 42)

    state.update(to: 84)

    #expect(state.current == 84)
    #expect(state.last == 42)
  }
}
