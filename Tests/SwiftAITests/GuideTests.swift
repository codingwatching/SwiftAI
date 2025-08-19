import Foundation
import SwiftAI
import Testing

// TODO: Revist this test file and see if we need more tests, if we can improve the structure, or if we can remove some tests.

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
    name: "PrimitiveTypes",
    description: nil,
    properties: [
      "str": Schema.Property(
        schema: .string(constraints: []),
        description: "str field",
        isOptional: false),
      "int": Schema.Property(
        schema: .integer(constraints: []),
        description: "int field",
        isOptional: false),
      "double": Schema.Property(
        schema: .number(constraints: []),
        description: "double field",
        isOptional: false),
      "bool": Schema.Property(
        schema: .boolean(constraints: []),
        description: "bool field",
        isOptional: false),
    ]
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
    name: "OptionalPrimitiveTypes",
    description: nil,
    properties: [
      "optStr": Schema.Property(
        schema: .string(constraints: []),
        description: "optional str field",
        isOptional: true),
      "optInt": Schema.Property(
        schema: .integer(constraints: []),
        description: "optional int field",
        isOptional: true),
      "optDouble": Schema.Property(
        schema: .number(constraints: []),
        description: "optional double field",
        isOptional: true),
      "optBool": Schema.Property(
        schema: .boolean(constraints: []),
        description: "optional bool field",
        isOptional: true),
    ]
  )

  #expect(OptionalPrimitiveTypes.schema == expectedSchema)
}

@Generable
struct ArrayTypes {
  @Guide(description: "Simple string array")
  let strs: [String]

  @Guide(description: "Optional number array")
  let optionalArrayOfInts: [Int]?

  @Guide(description: "Array of arrays of strings")
  let arrayOfArraysOfStrs: [[String]]
}

@Test func arrayTypesSupport() throws {
  let expectedSchema = Schema.object(
    name: "ArrayTypes",
    description: nil,
    properties: [
      "strs": Schema.Property(
        schema: .array(
          items: .string(constraints: []),
          constraints: []),
        description: "Simple string array",
        isOptional: false),
      "optionalArrayOfInts": Schema.Property(
        schema: .array(
          items: .integer(constraints: []),
          constraints: []),
        description: "Optional number array",
        isOptional: true),
      "arrayOfArraysOfStrs": Schema.Property(
        schema: .array(
          items: .array(items: .string(constraints: []), constraints: []),
          constraints: []),
        description: "Array of arrays of strings",
        isOptional: false),
    ]
  )

  #expect(ArrayTypes.schema == expectedSchema)
}

@Generable
struct Constraints {
  @Guide(.pattern("[A-Z]+"))
  let str: String

  @Guide(.minimum(0), .maximum(100))
  let int: Int?

  @Guide(.range(0.01...9999.99))
  let double: Double

  @Guide<Bool>
  let bool: Bool

  @Guide(.minimumCount(1), .maximumCount(10), .element(.pattern("^[A-Z]{3}$")))
  let arrayOfStrs: [String]

  @Guide(
    .minimumCount(1),
    .maximumCount(10),
    .element(.count(3)),
    .element(.element(.pattern("^[A-Z]{3}$")))
  )
  let arrayOfArraysOfStrs: [[String]]
}

@Test func constrainedTypesSupport() throws {
  let expectedSchema = Schema.object(
    name: "Constraints",
    description: nil,
    properties: [
      "str": Schema.Property(
        schema: .string(
          constraints: [.pattern("[A-Z]+")]),
        description: nil,
        isOptional: false),
      "int": Schema.Property(
        schema: .integer(
          constraints: [.minimum(0), .maximum(100)]),
        description: nil,
        isOptional: true),
      "double": Schema.Property(
        schema: .number(
          constraints: [.range(0.01...9999.99)]),
        description: nil,
        isOptional: false),
      "bool": Schema.Property(
        schema: .boolean(
          constraints: []),
        description: nil,
        isOptional: false),
      "arrayOfStrs": Schema.Property(
        schema: .array(
          items: .string(constraints: [.pattern("^[A-Z]{3}$")]),
          constraints: [
            AnyArrayConstraint(Constraint<[String]>.minimumCount(1)),
            AnyArrayConstraint(Constraint<[String]>.maximumCount(10)),
          ]),
        description: nil,
        isOptional: false),
      "arrayOfArraysOfStrs": Schema.Property(
        schema: .array(
          items: .array(
            items: .string(constraints: [.pattern("^[A-Z]{3}$")]),
            constraints: [
              AnyArrayConstraint(Constraint<[String]>.count(3))
            ]
          ),
          constraints: [
            AnyArrayConstraint(Constraint<[[String]]>.minimumCount(1)),
            AnyArrayConstraint(Constraint<[[String]]>.maximumCount(10)),
          ]
        ),
        description: nil,
        isOptional: false),
    ]
  )

  #expect(Constraints.schema == expectedSchema)
}

@Generable
struct DescriptionsWithConstraints {
  @Guide(description: "str field with constraints", .pattern("^[A-Z][a-z]+$"))
  let str: String

  @Guide(description: "int field with constraints", .minimum(18), .maximum(100))
  let int: Int

  @Guide(description: "double field with constraints", .minimum(0.0))
  let double: Double?

  @Guide(description: "string array with constraints", .minimumCount(1), .element(.pattern(".+")))
  let strs: [String]
}

@Test func descriptionsWithConstraintsSupport() throws {
  let expectedSchema = Schema.object(
    name: "DescriptionsWithConstraints",
    description: nil,
    properties: [
      "str": Schema.Property(
        schema: .string(
          constraints: [.pattern("^[A-Z][a-z]+$")]
        ),
        description: "str field with constraints",
        isOptional: false),
      "int": Schema.Property(
        schema: .integer(
          constraints: [.minimum(18), .maximum(100)]
        ),
        description: "int field with constraints",
        isOptional: false),
      "double": Schema.Property(
        schema: .number(
          constraints: [.minimum(0.0)]
        ),
        description: "double field with constraints",
        isOptional: true),
      "strs": Schema.Property(
        schema: .array(
          items: .string(constraints: [.pattern(".+")]),
          constraints: [
            AnyArrayConstraint(Constraint<[String]>.minimumCount(1))
          ]
        ),
        description: "string array with constraints",
        isOptional: false),
    ]
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
    name: "CustomTypes",
    description: nil,
    properties: [
      "str": Schema.Property(
        schema: .string(constraints: []),
        description: "main str field",
        isOptional: false),
      "nested": Schema.Property(
        schema: NestedType.schema,
        description: "required nested type",
        isOptional: false),
      "optNested": Schema.Property(
        schema: NestedType.schema,
        description: "optional nested type",
        isOptional: true),
      "nestedArray": Schema.Property(
        schema: .array(
          items: NestedType.schema,
          constraints: []),
        description: "array of nested types",
        isOptional: false),
    ]
  )

  #expect(CustomTypes.schema == expectedSchema)
}

@Generable
struct ExplicitConstraintTypes {
  @Guide(Constraint<String>.pattern("[A-Z]+"))
  let str: String

  @Guide(Constraint<Int>.minimum(0), Constraint<Int>.maximum(100))
  let int: Int?

  @Guide(Constraint<Double>.range(0.01...9999.99))
  let double: Double

  @Guide<Bool>
  let bool: Bool

  @Guide(
    Constraint<[String]>.minimumCount(1), Constraint<[String]>.maximumCount(10),
    Constraint<[String]>.element(Constraint<String>.pattern("^[A-Z]{3}$")))
  let arrayOfStrs: [String]

  @Guide(
    Constraint<[[String]]>.minimumCount(1),
    Constraint<[[String]]>.maximumCount(10),
    Constraint<[[String]]>.element(Constraint<[String]>.count(3)),
    Constraint<[[String]]>.element(
      Constraint<[String]>.element(Constraint<String>.pattern("^[A-Z]{3}$")))
  )
  let arrayOfArraysOfStrs: [[String]]
}

@Test func explicitConstraintTypesSupport() throws {
  let expectedSchema = Schema.object(
    name: "ExplicitConstraintTypes",
    description: nil,
    properties: [
      "str": Schema.Property(
        schema: .string(
          constraints: [.pattern("[A-Z]+")]),
        description: nil,
        isOptional: false),
      "int": Schema.Property(
        schema: .integer(
          constraints: [.minimum(0), .maximum(100)]),
        description: nil,
        isOptional: true),
      "double": Schema.Property(
        schema: .number(
          constraints: [.range(0.01...9999.99)]),
        description: nil,
        isOptional: false),
      "bool": Schema.Property(
        schema: .boolean(
          constraints: []),
        description: nil,
        isOptional: false),
      "arrayOfStrs": Schema.Property(
        schema: .array(
          items: .string(constraints: [.pattern("^[A-Z]{3}$")]),
          constraints: [
            AnyArrayConstraint(Constraint<[String]>.minimumCount(1)),
            AnyArrayConstraint(Constraint<[String]>.maximumCount(10)),
          ]),
        description: nil,
        isOptional: false),
      "arrayOfArraysOfStrs": Schema.Property(
        schema: .array(
          items: .array(
            items: .string(constraints: [.pattern("^[A-Z]{3}$")]),
            constraints: [
              AnyArrayConstraint(Constraint<[String]>.count(3))
            ]),
          constraints: [
            AnyArrayConstraint(Constraint<[[String]]>.minimumCount(1)),
            AnyArrayConstraint(Constraint<[[String]]>.maximumCount(10)),
          ]),
        description: nil,
        isOptional: false),
    ]
  )

  #expect(ExplicitConstraintTypes.schema == expectedSchema)
}
