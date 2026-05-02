import Foundation

enum QueryResult<Value: Encodable> {
  case many([Value])
  case one(Value?)
}
