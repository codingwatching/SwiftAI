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
  let schema = Schema.string(constraints: [])
  let json = try schema.toGenerationSchema().json()
  #expect(json["type"] as? String == "string")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func primitiveIntegerConversion() throws {
  let schema = Schema.integer(constraints: [])
  let json = try schema.toGenerationSchema().json()
  #expect(json["type"] as? String == "integer")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func anyOfConversion() throws {
  let schema = Schema.anyOf(
    name: "StringOrInt",
    description: "Either a string or an integer",
    schemas: [
      Schema.string(constraints: []),
      Schema.integer(constraints: []),
    ]
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["title"] as? String == "StringOrInt")
  #expect(json["description"] as? String == "Either a string or an integer")

  let anyOfArray = json["anyOf"] as? [[String: Any]]
  #expect(anyOfArray != nil)
  #expect(anyOfArray?.count == 2)

  let types = anyOfArray?.compactMap { $0["type"] as? String }.sorted()
  #expect(types == ["integer", "string"])
}

@available(iOS 26.0, macOS 26.0, *)
@Test func simpleObjectConversion() throws {
  let properties = [
    "name": Schema.Property(schema: .string(constraints: []), description: nil, isOptional: false),
    "age": Schema.Property(schema: .integer(constraints: []), description: nil, isOptional: true),
  ]
  let schema = Schema.object(
    name: "Person", description: "Basic information about a person", properties: properties)
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "object")
  #expect(json["title"] as? String == "Person")
  #expect(json["description"] as? String == "Basic information about a person")

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
@Test func arraySchemaConversion() throws {
  let schema = Schema.array(
    items: .string(constraints: []),
    constraints: []
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "array")

  let items = json["items"] as? [String: Any]
  #expect(items != nil)
  #expect(items?["type"] as? String == "string")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func nestedArraySchemaConversion() throws {
  let schema = Schema.array(
    items: .array(
      items: .integer(constraints: []),
      constraints: []
    ),
    constraints: []
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "array")

  let items = json["items"] as? [String: Any]
  #expect(items != nil)
  #expect(items?["type"] as? String == "array")

  let nestedItems = items?["items"] as? [String: Any]
  #expect(nestedItems != nil)
  #expect(nestedItems?["type"] as? String == "integer")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func arrayWithObjectTypeConversion() throws {
  let arraySchema = Schema.array(
    items: Schema.object(
      name: "Person",
      description: "A person object",
      properties: [
        "name": Schema.Property(
          schema: .string(constraints: []), description: "Person's name", isOptional: false),
        "age": Schema.Property(
          schema: .integer(constraints: []), description: "Person's age", isOptional: true),
      ]
    ),
    constraints: []
  )

  let json = try arraySchema.toGenerationSchema().json()

  #expect(json["type"] as? String == "array")

  // Check that items uses a JSON Schema reference
  let items = json["items"] as? [String: Any]
  #expect(items != nil)

  // FoundationModels uses $ref for complex schemas
  let ref = items?["$ref"] as? String
  #expect(ref == "#/$defs/Person")

  // The actual schema definition should be in $defs
  let defs = json["$defs"] as? [String: [String: Any]]
  #expect(defs != nil)

  let personDef = defs?["Person"] as? [String: Any]
  #expect(personDef != nil)
  #expect(personDef?["type"] as? String == "object")
  #expect(personDef?["title"] as? String == "Person")
  #expect(personDef?["description"] as? String == "A person object")

  let properties = personDef?["properties"] as? [String: [String: Any]]
  #expect(properties != nil)
  #expect(properties?.keys.contains("name") == true)
  #expect(properties?.keys.contains("age") == true)

  // Check that property descriptions are preserved
  #expect(properties?["name"]?["description"] as? String == "Person's name")
  #expect(properties?["age"]?["description"] as? String == "Person's age")

  // Check required fields
  let required = personDef?["required"] as? [String]
  #expect(required?.contains("name") == true)
  #expect(required?.contains("age") == false)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func propertyDescriptionConversion() throws {
  let properties = [
    "title": Schema.Property(
      schema: .string(constraints: []),
      description: "The title of the item",
      isOptional: false
    ),
    "count": Schema.Property(
      schema: .integer(constraints: []),
      description: "Number of items",
      isOptional: true
    ),
    "tags": Schema.Property(
      schema: .array(items: .string(constraints: []), constraints: []),
      description: "List of tags",
      isOptional: false
    ),
  ]
  let schema = Schema.object(
    name: "Item",
    description: "An item with descriptions",
    properties: properties
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "object")
  #expect(json["title"] as? String == "Item")
  #expect(json["description"] as? String == "An item with descriptions")

  let propertiesDict = json["properties"] as? [String: [String: Any]]
  #expect(propertiesDict != nil)

  // Verify property descriptions are included
  #expect(propertiesDict?["title"]?["description"] as? String == "The title of the item")
  #expect(propertiesDict?["count"]?["description"] as? String == "Number of items")
  #expect(propertiesDict?["tags"]?["description"] as? String == "List of tags")

  // Verify required fields
  let required = json["required"] as? [String]
  #expect(required?.contains("title") == true)
  #expect(required?.contains("tags") == true)
  #expect(required?.contains("count") == false)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func objectWithoutDescriptionConversion() throws {
  let properties = [
    "value": Schema.Property(schema: .string(constraints: []), description: nil, isOptional: false)
  ]
  let schema = Schema.object(
    name: "SimpleObject",
    description: nil,
    properties: properties
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "object")
  #expect(json["title"] as? String == "SimpleObject")
  #expect(json["description"] == nil)

  let propertiesDict = json["properties"] as? [String: [String: Any]]
  #expect(propertiesDict != nil)
  #expect(propertiesDict?["value"]?["description"] == nil)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func anyOfWithDescriptionsConversion() throws {
  let stringSchema = Schema.string(constraints: [])
  let numberSchema = Schema.number(constraints: [])

  let schema = Schema.anyOf(
    name: "StringOrNumber",
    description: "Either a string or a number value",
    schemas: [stringSchema, numberSchema]
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["title"] as? String == "StringOrNumber")
  #expect(json["description"] as? String == "Either a string or a number value")

  let anyOfArray = json["anyOf"] as? [[String: Any]]
  #expect(anyOfArray != nil)
  #expect(anyOfArray?.count == 2)

  let types = anyOfArray?.compactMap { $0["type"] as? String }.sorted()
  #expect(types == ["number", "string"])
}

@available(iOS 26.0, macOS 26.0, *)
extension GenerationSchema {
  func json() throws -> [String: Any] {
    let jsonData = try JSONEncoder().encode(self)
    return try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
  }
}
#endif
