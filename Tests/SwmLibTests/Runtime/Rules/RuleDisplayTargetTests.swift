import Testing

@testable import SwmLib

@Suite("RuleDisplayTarget")
struct RuleDisplayTargetTests {
  @Test("resolve: finds parsed indexes and UUIDs independent of the source")
  func resolveFindsParsedIndexesAndUUIDsIndependentOfTheSource() throws {
    let first = "C9229BE8-0C61-4A38-A339-AD5D6B07A215"
    let second = "F642B30E-6488-455C-B0C4-3B365F9D3D0E"
    #expect(RuleDisplayTarget(argument: "2")?.resolve(in: [first, second]) == second)
    #expect(RuleDisplayTarget(argument: "3")?.resolve(in: [first, second]) == nil)
    let target = try #require(RuleDisplayTarget(argument: second.lowercased()))
    #expect(target.resolve(in: [second, first]) == second)
    #expect(target.resolve(in: [first]) == nil)
  }
}
