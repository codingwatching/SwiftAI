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
      @Generable
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
        let optionalArrayOfOptionalInts: [Int?]?
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
          let optionalArrayOfOptionalInts: [Int?]?
        }

        extension AllTypes: Generable {
          public static var schema: Schema {
            .object(
              properties: [
                "stringField": Schema.Property(
                  schema: .string(constraints: [], metadata: nil),
                  isOptional: false
                ),
                "intField": Schema.Property(
                  schema: .integer(constraints: [], metadata: nil),
                  isOptional: false
                ),
                "doubleField": Schema.Property(
                  schema: .number(constraints: [], metadata: nil),
                  isOptional: false
                ),
                "boolField": Schema.Property(
                  schema: .boolean(constraints: [], metadata: nil),
                  isOptional: false
                ),
                "optionalString": Schema.Property(
                  schema: .string(constraints: [], metadata: nil),
                  isOptional: true
                ),
                "optionalInt": Schema.Property(
                  schema: .integer(constraints: [], metadata: nil),
                  isOptional: true
                ),
                "arrayOfStrings": Schema.Property(
                  schema: .array(
                    items: .string(constraints: [], metadata: nil),
                    constraints: [],
                    metadata: nil
                  ),
                  isOptional: false
                ),
                "arrayOfInts": Schema.Property(
                  schema: .array(
                    items: .integer(constraints: [], metadata: nil),
                    constraints: [],
                    metadata: nil
                  ),
                  isOptional: false
                ),
                "optionalArrayOfBools": Schema.Property(
                  schema: .array(
                    items: .boolean(constraints: [], metadata: nil),
                    constraints: [],
                    metadata: nil
                  ),
                  isOptional: true
                ),
                "customType": Schema.Property(
                  schema: CustomStruct.schema,
                  isOptional: false
                ),
                "optionalArrayOfOptionalInts": Schema.Property(
                  schema: .array(
                    items: .integer(constraints: [], metadata: nil),
                    constraints: [],
                    metadata: nil
                  ),
                  isOptional: true
                ),
              ],
              metadata: nil
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
              properties: [
                "name": Schema.Property(
                  schema: .string(constraints: [], metadata: nil),
                  isOptional: false
                )
              ],
              metadata: nil
            )
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }
}
