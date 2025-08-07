import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SwiftAIMacros

final class SwiftAIMacrosTests: XCTestCase {
  let testMacros: [String: Macro.Type] = [
    "Generable": GenerableMacro.self
  ]

  func testBasicGenerableExpansion() throws {
    assertMacroExpansion(
      """
      @Generable
      struct Person {
          let name: String
          let age: Int
      }
      """,
      expandedSource: """
        struct Person {
            let name: String
            let age: Int
        }

        extension Person: Generable {
            public static var schema: Schema {
              .object(properties: ["name": Schema.Property(
              schema: .string(constraints: [], metadata: nil),
              isOptional: false
                          ),
                  "age": Schema.Property(
              schema: .integer(constraints: [], metadata: nil),
              isOptional: false
                          )], metadata: nil)
            }
        }
        """,
      macros: testMacros
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
              .object(properties: ["name": Schema.Property(
              schema: .string(constraints: [], metadata: nil),
              isOptional: false
                          )], metadata: nil)
            }
        }
        """,
      macros: testMacros
    )
  }

  func testCustomTypeUsesSchema() throws {
    assertMacroExpansion(
      """
      @Generable
      struct User {
          let name: String
          let address: Address
      }
      """,
      expandedSource: """
        struct User {
            let name: String
            let address: Address
        }

        extension User: Generable {
            public static var schema: Schema {
              .object(properties: ["name": Schema.Property(
              schema: .string(constraints: [], metadata: nil),
              isOptional: false
                          ),
                  "address": Schema.Property(
              schema: Address.schema,
              isOptional: false
                          )], metadata: nil)
            }
        }
        """,
      macros: testMacros
    )
  }
}
