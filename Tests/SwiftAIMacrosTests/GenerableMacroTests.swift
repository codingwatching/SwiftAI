import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SwiftAIMacros

final class GenerableMacroTests: XCTestCase {
  let testMacros: [String: Macro.Type] = [
    "Generable": GenerableMacro.self
  ]

  func testAllBasicTypes() throws {
    assertMacroExpansion(
      """
      @Generable(description: "A struct with all basic types")
      struct AllTypes {
        let stringField: String
        let intField: Int
        let doubleField: Double
        let boolField: Bool
        let optionalString: String?
        let optionalInt: Int?
        let arrayOfStrings: [String]
        let arrayOfInts: [Int]
        let optionalArrayOfBools: [Bool]?
        let customType: CustomStruct
      }
      """,
      expandedSource: """
        struct AllTypes {
          let stringField: String
          let intField: Int
          let doubleField: Double
          let boolField: Bool
          let optionalString: String?
          let optionalInt: Int?
          let arrayOfStrings: [String]
          let arrayOfInts: [Int]
          let optionalArrayOfBools: [Bool]?
          let customType: CustomStruct
        }

        extension AllTypes: Generable {
          public static var schema: Schema {
            .object(
              name: "AllTypes",
              description: nil,
              properties: [
                "stringField": Schema.Property(
                  schema: .string(constraints: []),
                  description: nil,
                  isOptional: false
                ),
                "intField": Schema.Property(
                  schema: .integer(constraints: []),
                  description: nil,
                  isOptional: false
                ),
                "doubleField": Schema.Property(
                  schema: .number(constraints: []),
                  description: nil,
                  isOptional: false
                ),
                "boolField": Schema.Property(
                  schema: .boolean(constraints: []),
                  description: nil,
                  isOptional: false
                ),
                "optionalString": Schema.Property(
                  schema: .string(constraints: []),
                  description: nil,
                  isOptional: true
                ),
                "optionalInt": Schema.Property(
                  schema: .integer(constraints: []),
                  description: nil,
                  isOptional: true
                ),
                "arrayOfStrings": Schema.Property(
                  schema: .array(items: .string(constraints: []), constraints: []),
                  description: nil,
                  isOptional: false
                ),
                "arrayOfInts": Schema.Property(
                  schema: .array(items: .integer(constraints: []), constraints: []),
                  description: nil,
                  isOptional: false
                ),
                "optionalArrayOfBools": Schema.Property(
                  schema: .array(items: .boolean(constraints: []), constraints: []),
                  description: nil,
                  isOptional: true
                ),
                "customType": Schema.Property(
                  schema: CustomStruct.schema,
                  description: nil,
                  isOptional: false
                ),
              ]

            )
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  func testPropertiesWithDefaultValuesAreExcluded() throws {
    assertMacroExpansion(
      """
      @Generable
      struct User {
        let name: String
        let isActive: Bool = true
      }
      """,
      expandedSource: """
        struct User {
          let name: String
          let isActive: Bool = true
        }

        extension User: Generable {
          public static var schema: Schema {
            .object(
              name: "User",
              description: nil,
              properties: [
                "name": Schema.Property(
                  schema: .string(constraints: []),
                  description: nil,
                  isOptional: false
                )
              ]

            )
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  func testArrayOfOptionalTypesRejected() throws {
    assertMacroExpansion(
      """
      @Generable
      struct InvalidType {
        let problematicProperty: [Int?]
      }
      """,
      expandedSource: """
        struct InvalidType {
          let problematicProperty: [Int?]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Property 'problematicProperty' cannot be an array of optional types '[Int?]'. Arrays of optionals are not supported. Consider using a different data structure or making the entire array optional instead.",
          line: 1, column: 1)
      ],
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  func testGuideWithConstraints() throws {
    assertMacroExpansion(
      """
      @Generable
      struct ConstrainedFields {
        @Guide(.pattern("[A-Z]+"), .minLength(5))
        let name: String
        
        @Guide(description: "User age in years", .minimum(18), .maximum(100))
        let age: Int
        
        @Guide(.minimum(0.0))
        let score: Double?
        
        @Guide(description: "Tags array", .minimumCount(1), .element(.minLength(2)))
        let tags: [String]
      }
      """,
      expandedSource: """
        struct ConstrainedFields {
          @Guide(.pattern("[A-Z]+"), .minLength(5))
          let name: String
          
          @Guide(description: "User age in years", .minimum(18), .maximum(100))
          let age: Int
          
          @Guide(.minimum(0.0))
          let score: Double?
          
          @Guide(description: "Tags array", .minimumCount(1), .element(.minLength(2)))
          let tags: [String]
        }

        extension ConstrainedFields: Generable {
          public static var schema: Schema {
            .object(
              name: "ConstrainedFields",
              description: nil,
              properties: [
                "name": Schema.Property(
                  schema: .string(constraints: [.pattern("[A-Z]+"), .minLength(5)]),
                  description: nil,
                  isOptional: false
                ),
                "age": Schema.Property(
                  schema: .integer(constraints: [.minimum(18), .maximum(100)]),
                  description: "User age in years",
                  isOptional: false
                ),
                "score": Schema.Property(
                  schema: .number(constraints: [.minimum(0.0)]),
                  description: nil,
                  isOptional: true
                ),
                "tags": Schema.Property(
                  schema: .array(
                    items: .string(constraints: []),
                    constraints: [
                      AnyArrayConstraint(Constraint<[String]>.minimumCount(1)),
                      AnyArrayConstraint(Constraint<[String]>.element(.minLength(2))),
                    ]
                  ),
                  description: "Tags array",
                  isOptional: false
                ),
              ]

            )
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }
}
