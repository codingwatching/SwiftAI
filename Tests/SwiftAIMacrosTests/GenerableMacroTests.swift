import MacroTesting
import SwiftAIMacros
import Testing

@Suite(.macros(["Generable": GenerableMacro.self]))
struct GenerableMacroTests {
  @Test
  func testAllBasicTypes() throws {
    assertMacro(indentationWidth: .spaces(2)) {
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
      """
    } expansion: {
      """
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

      extension AllTypes: SwiftAI.Generable {
        public static var schema: Schema {
          .object(
            name: "AllTypes",
            description: nil,
            properties: [
              "stringField": Schema.Property(
                schema: String.schema,
                description: nil,
                isOptional: false
              ),
              "intField": Schema.Property(
                schema: Int.schema,
                description: nil,
                isOptional: false
              ),
              "doubleField": Schema.Property(
                schema: Double.schema,
                description: nil,
                isOptional: false
              ),
              "boolField": Schema.Property(
                schema: Bool.schema,
                description: nil,
                isOptional: false
              ),
              "optionalString": Schema.Property(
                schema: String.schema,
                description: nil,
                isOptional: true
              ),
              "optionalInt": Schema.Property(
                schema: Int.schema,
                description: nil,
                isOptional: true
              ),
              "arrayOfStrings": Schema.Property(
                schema: [String].schema,
                description: nil,
                isOptional: false
              ),
              "arrayOfInts": Schema.Property(
                schema: [Int].schema,
                description: nil,
                isOptional: false
              ),
              "optionalArrayOfBools": Schema.Property(
                schema: [Bool].schema,
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

        public var generableContent: StructuredContent {
          StructuredContent(
            kind: .object([
              "stringField": self.stringField.generableContent,
              "intField": self.intField.generableContent,
              "doubleField": self.doubleField.generableContent,
              "boolField": self.boolField.generableContent,
              "optionalString": self.optionalString?.generableContent
                ?? StructuredContent(kind: .null),
              "optionalInt": self.optionalInt?.generableContent
                ?? StructuredContent(kind: .null),
              "arrayOfStrings": self.arrayOfStrings.generableContent,
              "arrayOfInts": self.arrayOfInts.generableContent,
              "optionalArrayOfBools": self.optionalArrayOfBools?.generableContent
                ?? StructuredContent(kind: .null),
              "customType": self.customType.generableContent,
            ])
          )
        }
      }
      """
    }
  }

  @Test
  func testPropertiesWithDefaultValuesAreExcluded() throws {
    assertMacro(indentationWidth: .spaces(2)) {
      """
      @Generable
      struct User {
        let name: String
        let isActive: Bool = true
      }
      """
    } expansion: {
      """
      struct User {
        let name: String
        let isActive: Bool = true
      }

      extension User: SwiftAI.Generable {
        public static var schema: Schema {
          .object(
            name: "User",
            description: nil,
            properties: [
              "name": Schema.Property(
                schema: String.schema,
                description: nil,
                isOptional: false
              )
            ]
          )
        }

        public var generableContent: StructuredContent {
          StructuredContent(kind: .object(["name": self.name.generableContent]))
        }
      }
      """
    }
  }

  @Test
  func testArrayOfOptionalTypesRejected() throws {
    assertMacro {
      """
      @Generable
      struct InvalidType {
        let problematicProperty: [Int?]
      }
      """
    } diagnostics: {
      """
      @Generable
      ┬─────────
      ╰─ 🛑 Property 'problematicProperty' cannot be an array of optional types '[Int?]'. Arrays of optionals are not supported. Consider using a different data structure or making the entire array optional instead.
      struct InvalidType {
        let problematicProperty: [Int?]
      }
      """
    }
  }

  @Test
  func testGuideWithConstraints() throws {
    assertMacro(indentationWidth: .spaces(2)) {
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
      """
    } expansion: {
      """
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

      extension ConstrainedFields: SwiftAI.Generable {
        public static var schema: Schema {
          .object(
            name: "ConstrainedFields",
            description: nil,
            properties: [
              "name": Schema.Property(
                schema: String.schema.withConstraints([
                  .pattern("[A-Z]+"), .minLength(5),
                ]),
                description: nil,
                isOptional: false
              ),
              "age": Schema.Property(
                schema: Int.schema.withConstraints([.minimum(18), .maximum(100)]),
                description: "User age in years",
                isOptional: false
              ),
              "score": Schema.Property(
                schema: Double.schema.withConstraints([.minimum(0.0)]),
                description: nil,
                isOptional: true
              ),
              "tags": Schema.Property(
                schema: [String].schema.withConstraints([
                  .minimumCount(1), .element(.minLength(2)),
                ]),
                description: "Tags array",
                isOptional: false
              ),
            ]
          )
        }

        public var generableContent: StructuredContent {
          StructuredContent(
            kind: .object([
              "name": self.name.generableContent, "age": self.age.generableContent,
              "score": self.score?.generableContent ?? StructuredContent(kind: .null),
              "tags": self.tags.generableContent,
            ])
          )
        }
      }
      """
    }
  }

  @Test
  func testGuideWithExplicitConstraintTypes() throws {
    assertMacro(indentationWidth: .spaces(2)) {
      """
      @Generable
      struct ExplicitConstraintFields {
        @Guide(Constraint<String>.pattern("[A-Z]+"), Constraint<String>.minLength(5))
        let name: String
        
        @Guide(description: "User age in years", Constraint<Int>.minimum(18), Constraint<Int>.maximum(100))
        let age: Int
        
        @Guide(Constraint<Double>.minimum(0.0))
        let score: Double?
        
        @Guide(description: "Tags array", Constraint<[String]>.minimumCount(1), Constraint<[String]>.element(Constraint<String>.minLength(2)))
        let tags: [String]
      }
      """
    } expansion: {
      """
      struct ExplicitConstraintFields {
        @Guide(Constraint<String>.pattern("[A-Z]+"), Constraint<String>.minLength(5))
        let name: String
        
        @Guide(description: "User age in years", Constraint<Int>.minimum(18), Constraint<Int>.maximum(100))
        let age: Int
        
        @Guide(Constraint<Double>.minimum(0.0))
        let score: Double?
        
        @Guide(description: "Tags array", Constraint<[String]>.minimumCount(1), Constraint<[String]>.element(Constraint<String>.minLength(2)))
        let tags: [String]
      }

      extension ExplicitConstraintFields: SwiftAI.Generable {
        public static var schema: Schema {
          .object(
            name: "ExplicitConstraintFields",
            description: nil,
            properties: [
              "name": Schema.Property(
                schema: String.schema.withConstraints([
                  Constraint<String> .pattern("[A-Z]+"),
                  Constraint<String> .minLength(5),
                ]),
                description: nil,
                isOptional: false
              ),
              "age": Schema.Property(
                schema: Int.schema.withConstraints([
                  Constraint<Int> .minimum(18), Constraint<Int> .maximum(100),
                ]),
                description: "User age in years",
                isOptional: false
              ),
              "score": Schema.Property(
                schema: Double.schema.withConstraints([
                  Constraint<Double> .minimum(0.0)
                ]),
                description: nil,
                isOptional: true
              ),
              "tags": Schema.Property(
                schema: [String].schema.withConstraints([
                  Constraint<[String]> .minimumCount(1),
                  Constraint<[String]> .element(Constraint<String> .minLength(2)),
                ]),
                description: "Tags array",
                isOptional: false
              ),
            ]
          )
        }

        public var generableContent: StructuredContent {
          StructuredContent(
            kind: .object([
              "name": self.name.generableContent, "age": self.age.generableContent,
              "score": self.score?.generableContent ?? StructuredContent(kind: .null),
              "tags": self.tags.generableContent,
            ])
          )
        }
      }
      """
    }
  }
}
