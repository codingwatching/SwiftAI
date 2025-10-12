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

// MARK: - Typed Accessors

extension StructuredContent {
  /// Extracts a boolean value from this structured content.
  ///
  /// - Throws: If this content is not a boolean.
  /// - Returns: The boolean value.
  public var bool: Bool {
    get throws {
      guard case .bool(let value) = kind else {
        throw StructuredContentError.typeMismatch(expected: "bool", actual: kind.typeName)
      }
      return value
    }
  }

  /// Extracts a string value from this structured content.
  ///
  /// - Throws: If this content is not a string.
  /// - Returns: The string value.
  public var string: String {
    get throws {
      guard case .string(let value) = kind else {
        throw StructuredContentError.typeMismatch(expected: "string", actual: kind.typeName)
      }
      return value
    }
  }

  /// Extracts an integer value from this structured content.
  ///
  /// - Throws: If this content is not a number or cannot be represented as an integer.
  /// - Returns: The integer value.
  public var int: Int {
    get throws {
      guard case .number(let value) = kind else {
        throw StructuredContentError.typeMismatch(expected: "number", actual: kind.typeName)
      }
      guard value.rounded() == value else {
        throw StructuredContentError.invalidIntegerValue(value)
      }
      return Int(value)
    }
  }

  /// Extracts a double value from this structured content.
  ///
  /// - Throws: If this content is not a number.
  /// - Returns: The double value.
  public var double: Double {
    get throws {
      guard case .number(let value) = kind else {
        throw StructuredContentError.typeMismatch(expected: "number", actual: kind.typeName)
      }
      return value
    }
  }

  /// Extracts an object (dictionary) from this structured content.
  ///
  /// - Throws: If this content is not an object.
  /// - Returns: The object as a dictionary.
  public var object: [String: StructuredContent] {
    get throws {
      guard case .object(let value) = kind else {
        throw StructuredContentError.typeMismatch(expected: "object", actual: kind.typeName)
      }
      return value
    }
  }

  /// Extracts an array from this structured content.
  ///
  /// - Throws: If this content is not an array.
  /// - Returns: The array of structured content items.
  public var array: [StructuredContent] {
    get throws {
      guard case .array(let value) = kind else {
        throw StructuredContentError.typeMismatch(expected: "array", actual: kind.typeName)
      }
      return value
    }
  }

  /// Checks if this structured content is null.
  ///
  /// - Returns: `true` if this content is null, `false` otherwise.
  public var isNull: Bool {
    if case .null = kind {
      return true
    }
    return false
  }
}

// MARK: - Errors

/// Errors that can occur when accessing structured content values.
public enum StructuredContentError: Error {
  /// A type mismatch occurred when accessing a value.
  case typeMismatch(expected: String, actual: String)

  /// A number value cannot be represented as an integer.
  case invalidIntegerValue(Double)
}

extension StructuredContent.Kind {
  fileprivate var typeName: String {
    switch self {
    case .bool: return "bool"
    case .null: return "null"
    case .number: return "number"
    case .string: return "string"
    case .object: return "object"
    case .array: return "array"
    }
  }
}
