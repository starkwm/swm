import Foundation

/// Query response that encodes either a collection or an optional single value.
enum QueryResult<Value: Encodable> {
  /// Collection result, used when a selector can match more than one item.
  case many([Value])

  /// Single result, used when a selector identifies one item or no item.
  case one(Value?)
}
