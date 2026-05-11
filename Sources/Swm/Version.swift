/// Build version embedded in the swm executable.
struct Version {
  /// Current generated version.
  static let current = Self(value: "v0.0.4")

  /// Version string printed by `swm --version`.
  let value: String
}
