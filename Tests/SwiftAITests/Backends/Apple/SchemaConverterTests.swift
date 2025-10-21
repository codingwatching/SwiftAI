#if canImport(FoundationModels)
import Foundation
import SwiftAI
import Testing
import FoundationModels
import OrderedCollections

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
@Test func stringPatternConstraintConversion() throws {
  let schema = Schema.string(constraints: [.pattern("^[A-Z][a-z]+$")])
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "string")
  #expect(json["pattern"] as? String == "^[A-Z][a-z]+$")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func stringConstantConstraintConversion() throws {
  let schema = Schema.string(constraints: [.constant("hello")])
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "string")
  // FoundationModels represents constants as single-value enums
  let enumValues = json["enum"] as? [String]
  #expect(enumValues == ["hello"])
}

@available(iOS 26.0, macOS 26.0, *)
@Test func stringAnyOfConstraintConversion() throws {
  let schema = Schema.string(constraints: [.anyOf(["red", "green", "blue"])])
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "string")
  let enumValues = json["enum"] as? [String]
  #expect(enumValues?.sorted() == ["blue", "green", "red"])
}

@available(iOS 26.0, macOS 26.0, *)
@Test func stringMultipleConstraintsConversion() throws {
  let constraints: [StringConstraint] = [
    .pattern("^[A-Z]"),
    .anyOf(["Alpha", "Beta", "Gamma"]),
  ]
  let schema = Schema.string(constraints: constraints)
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "string")
  #expect(json["pattern"] as? String == "^[A-Z]")
  let enumValues = json["enum"] as? [String]
  #expect(enumValues?.sorted() == ["Alpha", "Beta", "Gamma"])
}

@available(iOS 26.0, macOS 26.0, *)
@Test func primitiveIntegerConversion() throws {
  let schema = Schema.integer(constraints: [])
  let json = try schema.toGenerationSchema().json()
  #expect(json["type"] as? String == "integer")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func integerMinimumConstraintConversion() throws {
  let schema = Schema.integer(constraints: [.range(lowerBound: 10, upperBound: nil)])
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "integer")
  #expect(json["minimum"] as? Int == 10)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func integerMaximumConstraintConversion() throws {
  let schema = Schema.integer(constraints: [.range(lowerBound: nil, upperBound: 100)])
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "integer")
  #expect(json["maximum"] as? Int == 100)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func integerRangeConstraintConversion() throws {
  let schema = Schema.integer(constraints: [.range(lowerBound: 10, upperBound: 100)])
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "integer")
  #expect(json["minimum"] as? Int == 10)
  #expect(json["maximum"] as? Int == 100)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func integerMultipleConstraintsConversion() throws {
  let constraints: [IntConstraint] = [
    .range(lowerBound: 5, upperBound: nil),
    .range(lowerBound: nil, upperBound: 50),
  ]
  let schema = Schema.integer(constraints: constraints)
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "integer")
  #expect(json["minimum"] as? Int == 5)
  #expect(json["maximum"] as? Int == 50)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func primitiveNumberConversion() throws {
  let schema = Schema.number(constraints: [])
  let json = try schema.toGenerationSchema().json()
  #expect(json["type"] as? String == "number")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func numberMinimumConstraintConversion() throws {
  let schema = Schema.number(constraints: [.range(lowerBound: 10.5, upperBound: nil)])
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "number")
  #expect(json["minimum"] as? Double == 10.5)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func numberMaximumConstraintConversion() throws {
  let schema = Schema.number(constraints: [.range(lowerBound: nil, upperBound: 100.0)])
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "number")
  #expect(json["maximum"] as? Double == 100.0)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func numberRangeConstraintConversion() throws {
  let schema = Schema.number(constraints: [.range(lowerBound: 10.5, upperBound: 100.0)])
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "number")
  #expect(json["minimum"] as? Double == 10.5)
  #expect(json["maximum"] as? Double == 100.0)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func numberMultipleConstraintsConversion() throws {
  let constraints: [DoubleConstraint] = [
    .range(lowerBound: 5.25, upperBound: nil),
    .range(lowerBound: nil, upperBound: 50.75),
  ]
  let schema = Schema.number(constraints: constraints)
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "number")
  #expect(json["minimum"] as? Double == 5.25)
  #expect(json["maximum"] as? Double == 50.75)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func primitiveBooleanConversion() throws {
  let schema = Schema.boolean(constraints: [])
  let json = try schema.toGenerationSchema().json()
  #expect(json["type"] as? String == "boolean")
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
<<<<<<< HEAD
  let properties: OrderedDictionary<String, Schema.Property> = [
    "name": Schema.Property(schema: .string(constraints: []), description: nil, isOptional: false),
    "age": Schema.Property(schema: .integer(constraints: []), description: nil, isOptional: true),
=======
  let properties = [
    "name": Schema.Property(schema: .string(constraints: []), description: nil),
    "age": Schema.Property(
      schema: .optional(wrapped: .integer(constraints: [])),
      description: nil
    ),
>>>>>>> main
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
@Test func arrayMinimumCountConstraintConversion() throws {
  let schema = Schema.array(
    items: .string(constraints: []),
    constraints: [ArrayConstraint.count(lowerBound: 3, upperBound: nil)]
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "array")
  #expect(json["minItems"] as? Int == 3)
  #expect(json["maxItems"] == nil)

  let items = json["items"] as? [String: Any]
  #expect(items != nil)
  #expect(items?["type"] as? String == "string")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func arrayMaximumCountConstraintConversion() throws {
  let schema = Schema.array(
    items: .string(constraints: []),
    constraints: [ArrayConstraint.count(lowerBound: nil, upperBound: 10)]
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "array")
  #expect(json["minItems"] == nil)
  #expect(json["maxItems"] as? Int == 10)

  let items = json["items"] as? [String: Any]
  #expect(items != nil)
  #expect(items?["type"] as? String == "string")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func arrayCountConstraintConversion() throws {
  let schema = Schema.array(
    items: .string(constraints: []),
    constraints: [ArrayConstraint.count(lowerBound: 5, upperBound: 5)]
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "array")
  #expect(json["minItems"] as? Int == 5)
  #expect(json["maxItems"] as? Int == 5)

  let items = json["items"] as? [String: Any]
  #expect(items != nil)
  #expect(items?["type"] as? String == "string")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func arrayRangeCountConstraintConversion() throws {
  let schema = Schema.array(
    items: .integer(constraints: []),
    constraints: [
      ArrayConstraint.count(lowerBound: 2, upperBound: nil),
      ArrayConstraint.count(lowerBound: nil, upperBound: 8),
    ]
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "array")
  #expect(json["minItems"] as? Int == 2)
  #expect(json["maxItems"] as? Int == 8)

  let items = json["items"] as? [String: Any]
  #expect(items != nil)
  #expect(items?["type"] as? String == "integer")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func arrayElementConstraintConversion() throws {
  let schema = Schema.array(
    items: .string(constraints: [.pattern("^[A-Z][a-z]+$")]),
    constraints: []
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "array")

  let items = json["items"] as? [String: Any]
  #expect(items != nil)
  #expect(items?["type"] as? String == "string")
  #expect(items?["pattern"] as? String == "^[A-Z][a-z]+$")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func arrayElementIntegerConstraintConversion() throws {
  let schema = Schema.array(
    items: .integer(constraints: [.range(lowerBound: 10, upperBound: 100)]),
    constraints: []
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "array")

  let items = json["items"] as? [String: Any]
  #expect(items != nil)
  #expect(items?["type"] as? String == "integer")
  #expect(items?["minimum"] as? Int == 10)
  #expect(items?["maximum"] as? Int == 100)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func arrayMultipleElementConstraintsConversion() throws {
  let schema = Schema.array(
    items: .string(constraints: [
      .anyOf(["red", "green", "blue"]), .pattern("^[a-z]+$"), .pattern(".{3,}"),
    ]),
    constraints: []
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "array")

  let items = json["items"] as? [String: Any]
  #expect(items != nil)
  #expect(items?["type"] as? String == "string")

  // Original constraints from schema
  let enumValues = items?["enum"] as? [String]
  #expect(enumValues?.sorted() == ["blue", "green", "red"])

  // Element constraints applied - last constraint wins when multiple patterns exist
  #expect(items?["pattern"] as? String == ".{3,}")
}

@available(iOS 26.0, macOS 26.0, *)
@Test func arrayCountAndElementConstraintsConversion() throws {
  let schema = Schema.array(
    items: .number(constraints: [
      .range(lowerBound: 0.0, upperBound: nil),
      .range(lowerBound: nil, upperBound: 100.0),
    ]),
    constraints: [
      ArrayConstraint.count(lowerBound: 1, upperBound: nil),
      ArrayConstraint.count(lowerBound: nil, upperBound: 5),
    ]
  )
  let json = try schema.toGenerationSchema().json()

  #expect(json["type"] as? String == "array")
  #expect(json["minItems"] as? Int == 1)
  #expect(json["maxItems"] as? Int == 5)

  let items = json["items"] as? [String: Any]
  #expect(items != nil)
  #expect(items?["type"] as? String == "number")
  #expect(items?["minimum"] as? Double == 0.0)
  #expect(items?["maximum"] as? Double == 100.0)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func arrayWithObjectTypeConversion() throws {
  let arraySchema = Schema.array(
    items: Schema.object(
      name: "Person",
      description: "A person object",
      properties: [
        "name": Schema.Property(
          schema: .string(constraints: []), description: "Person's name"),
        "age": Schema.Property(
          schema: .optional(wrapped: .integer(constraints: [])),
          description: "Person's age"
        ),
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
  let properties: OrderedDictionary<String, Schema.Property> = [
    "title": Schema.Property(
      schema: .string(constraints: []),
      description: "The title of the item"
    ),
    "count": Schema.Property(
      schema: .optional(wrapped: .integer(constraints: [])),
      description: "Number of items"
    ),
    "tags": Schema.Property(
      schema: .array(items: .string(constraints: []), constraints: []),
      description: "List of tags"
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
<<<<<<< HEAD
  let properties: OrderedDictionary<String, Schema.Property> = [
    "value": Schema.Property(schema: .string(constraints: []), description: nil, isOptional: false)
=======
  let properties = [
    "value": Schema.Property(schema: .string(constraints: []), description: nil)
>>>>>>> main
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
