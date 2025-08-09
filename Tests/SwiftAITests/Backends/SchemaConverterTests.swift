#if canImport(FoundationModels)
import Foundation
import SwiftAI
import Testing
import FoundationModels

// TODO: Two ideas for testing the conversion of Schemas to GenerationSchema:
//   1. Assert against a known JSON structure (not future proof).
//   2. Manually create the expected GenerationSchema serialize both the got and expected GenerationSchema to JSON and compare them.

// TODO: Create a more comprehensive test suite for schema conversion.

@available(iOS 26.0, macOS 26.0, *)
@Test func primitiveStringConversion() throws {
  let schema = Schema.string(constraints: [], metadata: nil)
  let json = try schema.toGenerationSchema().json()
  #expect(json["type"] as? String == "string")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func primitiveIntegerConversion() throws {
  let schema = Schema.integer(constraints: [], metadata: nil)
  let json = try schema.toGenerationSchema().json()
  #expect(json["type"] as? String == "integer")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func anyOfConversion() throws {
  let schema = Schema.anyOf(
    schemas: [
      Schema.string(constraints: [], metadata: nil),
      Schema.integer(constraints: [], metadata: nil),
    ],
    metadata: Schema.Metadata(
      title: "StringOrInt",
      description: "Either a string or an integer"
    )
  )
  let json = try schema.toGenerationSchema().json()

  let anyOfArray = json["anyOf"] as? [[String: Any]]
  #expect(anyOfArray != nil)
  #expect(anyOfArray?.count == 2)

  let types = anyOfArray?.compactMap { $0["type"] as? String }.sorted()
  #expect(types == ["integer", "string"])
}

@available(iOS 26.0, macOS 26.0, *)
@Test func simpleObjectConversion() throws {
  let properties = [
    "name": Schema.Property(schema: .string(constraints: [], metadata: nil), isOptional: false),
    "age": Schema.Property(schema: .integer(constraints: [], metadata: nil), isOptional: true),
  ]
  let schema = Schema.object(properties: properties, metadata: Schema.Metadata(title: "Person"))
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "object")

  let propertiesDict = json["properties"] as? [String: [String: Any]]
  #expect(propertiesDict != nil)
  #expect(propertiesDict?.keys.contains("name") == true)
  #expect(propertiesDict?.keys.contains("age") == true)

  #expect(propertiesDict?["name"]?["type"] as? String == "string")
  #expect(propertiesDict?["age"]?["type"] as? String == "integer")

  let required = json["required"] as? [String]
  #expect(required?.contains("name") == true)
  #expect(required?.contains("age") == false)
}

@available(iOS 26.0, macOS 26.0, *)
extension GenerationSchema {
  func json() throws -> [String: Any] {
    let jsonData = try JSONEncoder().encode(self)
    return try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
  }
}
#endif
