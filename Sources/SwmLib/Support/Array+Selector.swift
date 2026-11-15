extension Array {
  func index(selector: String, label: (Element) -> String?) -> Int? {
    if let number = Int(selector) {
      return number > 0 && indices.contains(number - 1) ? number - 1 : nil
    }
    return firstIndex { label($0) == selector }
  }

  mutating func appendUniquelyLabeled(
    _ element: Element,
    kind: String,
    label: (Element) -> String?
  ) throws {
    if let value = label(element), contains(where: { label($0) == value }) {
      throw IPCCommandError.invalidRequest("\(kind) label already exists: \(value)")
    }
    append(element)
  }

  mutating func remove(selector: String, kind: String, label: (Element) -> String?) throws {
    guard let index = index(selector: selector, label: label) else {
      throw IPCCommandError.invalidRequest("\(kind) not found: \(selector)")
    }
    remove(at: index)
  }
}
