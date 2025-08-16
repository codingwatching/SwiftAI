import Foundation

/// Represents structured content that can hold various JSON-like data types.
///
/// This struct provides a type-safe way to represent and work with structured data
/// that can contain boolean values, null, integers, doubles, strings,
/// objects, and arrays.
public struct StructuredContent: Sendable, Equatable {
  /// Defines the possible types of structured content.
  public enum Kind: Sendable, Equatable {
    /// A boolean value.
    case bool(Bool)

    /// A null value.
    case null

    /// A numeric value (both integers and floating-point numbers).
    case number(Double)

    /// A string value.
    case string(String)

    // TODO: Add the order of the keys.
    /// An object containing key-value pairs of structured content.
    case object([String: StructuredContent])

    /// An array containing multiple structured content items.
    case array([StructuredContent])
  }

  /// The kind of content this structured content represents.
  public let kind: Kind

  /// Creates a new structured content instance with the specified kind.
  ///
  /// - Parameter kind: The kind of content to represent
  public init(kind: Kind) {
    self.kind = kind
  }

  /// Creates a new structured content instance from a JSON string.
  ///
  /// - Parameter json: The JSON string to parse
  /// - Throws: If the JSON string cannot be parsed
  public init(json: String) throws {
    guard let data = json.data(using: .utf8) else {
      throw NSError(
        domain: "StructuredContent", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON string as UTF-8 data"])
    }

    let jsonObject = try JSONSerialization.jsonObject(
      with: data,
      options: [.fragmentsAllowed]
    )
    try self.init(jsonObject: jsonObject)
  }

  /// Creates a new structured content instance from a JSON object.
  ///
  /// - Parameter jsonObject: The JSON object (from JSONSerialization)
  /// - Throws: If the JSON object cannot be converted to structured content
  public init(jsonObject: Any) throws {
    let kind = try Kind(from: jsonObject)
    self.init(kind: kind)
  }

  /// Returns a JSON string representation of the structured content.
  public var jsonString: String {
    guard
      let data = try? JSONSerialization.data(
        withJSONObject: asJsonObject,
        options: [.fragmentsAllowed]
      ),
      let jsonString = String(data: data, encoding: .utf8)
    else {
      assertionFailure("Failed to serialize structured content to JSON string")
      return "{}"
    }

    return jsonString
  }
}

// MARK: - JSON Conversion

extension StructuredContent.Kind {
  init(from jsonObject: Any) throws {
    switch jsonObject {
    case is NSNull:
      self = .null
    case let number as NSNumber:
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        self = .bool(number.boolValue)
        return
      }
      // Check the actual storage type.
      let objCType = String(cString: number.objCType)
      switch objCType {
      case "i", "s", "l", "q":  // Integer types
        self = .number(Double(number.intValue))
      case "f", "d":  // Float/Double types
        self = .number(number.doubleValue)
      default:
        // For other types, always use the double value
        self = .number(number.doubleValue)
      }
    case let string as String:
      self = .string(string)
    case let array as [Any]:
      self = .array(try array.map { try StructuredContent(jsonObject: $0) })
    case let dict as [String: Any]:
      self = .object(try dict.mapValues { try StructuredContent(jsonObject: $0) })
    default:
      assertionFailure("Unsupported JSON type for structured content")
      throw NSError(
        domain: "StructuredContent", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Unsupported JSON type for structured content"])
    }
  }
}

extension StructuredContent {
  var asJsonObject: Any {
    switch self.kind {
    case .bool(let bool):
      return bool
    case .null:
      return NSNull()
    case .number(let double):
      return double
    case .string(let string):
      return string
    case .array(let array):
      return array.map { $0.asJsonObject }
    case .object(let dict):
      return dict.mapValues { $0.asJsonObject }
    }
  }
}
