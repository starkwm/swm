extension Array {
  /// Return the position named by a one-based index or, for non-numeric selectors, a label.
  func index(selector: String, label: (Element) -> String?) -> Int? {
    if let number = Int(selector) {
      return number > 0 && indices.contains(number - 1) ? number - 1 : nil
    }
    return firstIndex { label($0) == selector }
  }
}
