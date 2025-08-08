import Foundation
import SwiftAI
import Testing

@Generable
struct PrimitiveTypes {
  @Guide(description: "str field")
  let str: String

  @Guide(description: "int field")
  let int: Int

  @Guide(description: "double field")
  let double: Double

  @Guide(description: "bool field")
  let bool: Bool
}

@Test func schemaGeneration_primitiveTypes() throws {
  let expectedSchema = Schema.object(
    properties: [
      "str": Schema.Property(
        schema: .string(
          constraints: [],
          metadata: .init(description: "str field")),
        isOptional: false),
      "int": Schema.Property(
        schema: .integer(
          constraints: [], metadata: .init(description: "int field")),
        isOptional: false),
      "double": Schema.Property(
        schema: .number(
          constraints: [], metadata: .init(description: "double field")),
        isOptional: false),
      "bool": Schema.Property(
        schema: .boolean(
          constraints: [], metadata: .init(description: "bool field")),
        isOptional: false),
    ],
    metadata: nil
  )

  #expect(PrimitiveTypes.schema == expectedSchema)
}

@Generable
struct OptionalPrimitiveTypes {
  @Guide(description: "optional str field")
  let optStr: String?

  @Guide(description: "optional int field")
  let optInt: Int?

  @Guide(description: "optional double field")
  let optDouble: Double?

  @Guide(description: "optional bool field")
  let optBool: Bool?
}

@Test func schemaGeneration_optionalPrimitiveTypes() throws {
  let expectedSchema = Schema.object(
    properties: [
      "optStr": Schema.Property(
        schema: .string(
          constraints: [],
          metadata: .init(description: "optional str field")),
        isOptional: true),
      "optInt": Schema.Property(
        schema: .integer(
          constraints: [], metadata: .init(description: "optional int field")),
        isOptional: true),
      "optDouble": Schema.Property(
        schema: .number(
          constraints: [], metadata: .init(description: "optional double field")),
        isOptional: true),
      "optBool": Schema.Property(
        schema: .boolean(
          constraints: [], metadata: .init(description: "optional bool field")),
        isOptional: true),
    ],
    metadata: nil
  )

  #expect(OptionalPrimitiveTypes.schema == expectedSchema)
}

@Generable
struct ArrayTypes {
  @Guide(description: "Simple string array")
  let strs: [String]

  @Guide(description: "Optional number array")
  let optionalArrayOfInts: [Int]?
}

@Test func arrayTypesSupport() throws {
  let expectedSchema = Schema.object(
    properties: [
      "strs": Schema.Property(
        schema: .array(
          items: .string(constraints: [], metadata: nil),
          constraints: [],
          metadata: Schema.Metadata(description: "Simple string array")),
        isOptional: false),
      "optionalArrayOfInts": Schema.Property(
        schema: .array(
          items: .integer(constraints: [], metadata: nil),
          constraints: [],
          metadata: Schema.Metadata(description: "Optional number array")),
        isOptional: true),
    ],
    metadata: nil
  )

  #expect(ArrayTypes.schema == expectedSchema)
}

@Generable
struct Constraints {
  @Guide(.pattern("[A-Z]+"), .minLength(7))
  let str: String

  @Guide(.minimum(0), .maximum(100))
  let int: Int?

  @Guide(.range(0.01...9999.99))
  let double: Double

  @Guide(.constant(true))
  let bool: Bool

  @Guide(.minimumCount(1), .maximumCount(10), .element(.pattern("^[A-Z]{3}$")))
  let arrayOfStrs: [String]
}

@Test func constrainedTypesSupport() throws {
  let expectedSchema = Schema.object(
    properties: [
      "str": Schema.Property(
        schema: .string(
          constraints: [.pattern("[A-Z]+"), .minLength(7)],
          metadata: nil),
        isOptional: false),
      "int": Schema.Property(
        schema: .integer(
          constraints: [.minimum(0), .maximum(100)],
          metadata: nil),
        isOptional: true),
      "double": Schema.Property(
        schema: .number(
          constraints: [.range(0.01...9999.99)],
          metadata: nil),
        isOptional: false),
      "bool": Schema.Property(
        schema: .boolean(
          constraints: [.constant(true)],
          metadata: nil),
        isOptional: false),
      "arrayOfStrs": Schema.Property(
        schema: .array(
          items: .string(constraints: [], metadata: nil),
          constraints: [
            AnyArrayConstraint(Constraint<[String]>.minimumCount(1)),
            AnyArrayConstraint(Constraint<[String]>.maximumCount(10)),
            AnyArrayConstraint(Constraint<[String]>.element(.pattern("^[A-Z]{3}$"))),
          ],
          metadata: nil),
        isOptional: false),
    ],
    metadata: nil
  )

  #expect(Constraints.schema == expectedSchema)
}

@Generable
struct DescriptionsWithConstraints {
  @Guide(description: "str field with constraints", .pattern("^[A-Z][a-z]+$"), .minLength(3))
  let str: String

  @Guide(description: "int field with constraints", .minimum(18), .maximum(100))
  let int: Int

  @Guide(description: "double field with constraints", .minimum(0.0))
  let double: Double?

  @Guide(description: "string array with constraints", .minimumCount(1), .element(.minLength(2)))
  let strs: [String]
}

@Test func descriptionsWithConstraintsSupport() throws {
  let expectedSchema = Schema.object(
    properties: [
      "str": Schema.Property(
        schema: .string(
          constraints: [.pattern("^[A-Z][a-z]+$"), .minLength(3)],
          metadata: Schema.Metadata(description: "str field with constraints")),
        isOptional: false),
      "int": Schema.Property(
        schema: .integer(
          constraints: [.minimum(18), .maximum(100)],
          metadata: Schema.Metadata(description: "int field with constraints")),
        isOptional: false),
      "double": Schema.Property(
        schema: .number(
          constraints: [.minimum(0.0)],
          metadata: Schema.Metadata(description: "double field with constraints")),
        isOptional: true),
      "strs": Schema.Property(
        schema: .array(
          items: .string(constraints: [], metadata: nil),
          constraints: [
            AnyArrayConstraint(Constraint<[String]>.minimumCount(1)),
            AnyArrayConstraint(Constraint<[String]>.element(.minLength(2))),
          ],
          metadata: Schema.Metadata(description: "string array with constraints")),
        isOptional: false),
    ],
    metadata: nil
  )

  #expect(DescriptionsWithConstraints.schema == expectedSchema)
}

@Generable
struct NestedType {
  @Guide(description: "nested str field")
  let str: String

  @Guide(description: "nested int field", .minimum(1))
  let int: Int
}

@Generable
struct CustomTypes {
  @Guide(description: "main str field")
  let str: String

  @Guide(description: "required nested type")
  let nested: NestedType

  @Guide(description: "optional nested type")
  let optNested: NestedType?

  @Guide(description: "array of nested types")
  let nestedArray: [NestedType]
}

@Test func customTypesSupport() throws {
  let expectedSchema = Schema.object(
    properties: [
      "str": Schema.Property(
        schema: .string(
          constraints: [],
          metadata: Schema.Metadata(description: "main str field")),
        isOptional: false),
      "nested": Schema.Property(
        schema: NestedType.schema,
        isOptional: false),
      "optNested": Schema.Property(
        schema: NestedType.schema,
        isOptional: true),
      "nestedArray": Schema.Property(
        schema: .array(
          items: NestedType.schema,
          constraints: [],
          metadata: Schema.Metadata(description: "array of nested types")),
        isOptional: false),
    ],
    metadata: nil
  )

  #expect(CustomTypes.schema == expectedSchema)
}
