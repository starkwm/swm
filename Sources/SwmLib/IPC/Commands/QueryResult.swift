import Foundation

/// A query response that can encode either a collection or an optional single value.
enum QueryResult<Value: Encodable> {
  /// A collection result, used when a selector can match more than one item.
  case many([Value])

  /// A single result, used when a selector identifies one item or no item.
  case one(Value?)
}
