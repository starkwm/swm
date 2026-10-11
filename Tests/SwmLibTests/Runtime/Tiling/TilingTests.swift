import Testing

@testable import SwmLib

@MainActor
@Suite("Tiling")
struct TilingTests {
  @Test(
    "layoutPlan: returns no frames for an empty automatic layout",
    arguments: [LayoutSelection.master, .dwindle, .monocle]
  )
  func layoutPlanReturnsNoFramesForAnEmptyAutomaticLayout(selection: LayoutSelection) {
    let tiling = makeTiling(windows: [], memberships: [:])
    tiling.initialize()
    #expect(tiling.setLayout(selection, for: 10))
    #expect(tiling.layoutPlan(for: layoutID(10)) == .layout(.frames([:])))
  }
}
