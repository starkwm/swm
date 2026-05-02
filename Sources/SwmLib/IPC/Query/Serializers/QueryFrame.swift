import CoreGraphics

struct QueryFrame: Codable, Equatable {
  let x: Double
  let y: Double
  let width: Double
  let height: Double

  init(_ rect: CGRect) {
    x = rect.origin.x
    y = rect.origin.y
    width = rect.size.width
    height = rect.size.height
  }
}
