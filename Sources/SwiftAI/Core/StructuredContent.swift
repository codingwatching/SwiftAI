import Foundation

/// Represents structured content that can hold various JSON-like data types.
///
/// This struct provides a type-safe way to represent and work with structured data
/// that can contain boolean values, null, integers, doubles, strings,
/// objects, and arrays.
public struct StructuredContent: Sendable, Equatable {
  /// The kind of content this structured content represents.
  public let kind: Kind

  /// Creates a new structured content instance with the specified kind.
  ///
  /// - Parameter kind: The kind of content to represent
  public init(kind: Kind) {
    self.kind = kind
  }

  /// Defines the possible types of structured content.
  public enum Kind: Sendable, Equatable {
    /// A boolean value.
    case bool(Bool)

    /// A null value.
    case null

    /// An integer value.
    case integer(Int)

    /// A floating-point number value.
    case number(Double)

    /// A string value.
    case string(String)

    // TODO: Add the order of the keys.
    /// An object containing key-value pairs of structured content.
    case object([String: StructuredContent])

    /// An array containing multiple structured content items.
    case array([StructuredContent])
  }
}
