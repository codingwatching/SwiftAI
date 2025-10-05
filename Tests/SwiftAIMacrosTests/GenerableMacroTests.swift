import MacroTesting
import SwiftAIMacros
import Testing

@Suite(.macros(["Generable": GenerableMacro.self]))
struct GenerableMacroTests {
  @Test
  func testAllBasicTypes() throws {
    assertMacro(indentationWidth: .spaces(2)) {
      """
      @Generable(description: "A struct with a mix of types")
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
        let arrayOfCustomTypes: [CustomStruct]
        let optionalArrayOfCustomTypes: [CustomStruct]?
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
        let arrayOfCustomTypes: [CustomStruct]
        let optionalArrayOfCustomTypes: [CustomStruct]?
      }

      nonisolated extension AllTypes: SwiftAI.Generable {
        public nonisolated struct Partial: SwiftAI.GenerableContentConvertible,
          Sendable
        {
          public let stringField: String.Partial?
          public let intField: Int.Partial?
          public let doubleField: Double.Partial?
          public let boolField: Bool.Partial?
          public let optionalString: String.Partial?
          public let optionalInt: Int.Partial?
          public let arrayOfStrings: [String].Partial?
          public let arrayOfInts: [Int].Partial?
          public let optionalArrayOfBools: [Bool].Partial?
          public let customType: CustomStruct.Partial?
          public let arrayOfCustomTypes: [CustomStruct].Partial?
          public let optionalArrayOfCustomTypes: [CustomStruct].Partial?

          public nonisolated var generableContent: StructuredContent {
            StructuredContent(
              kind: .object([
                "stringField": self.stringField?.generableContent
                  ?? StructuredContent(kind: .null),
                "intField": self.intField?.generableContent
                  ?? StructuredContent(kind: .null),
                "doubleField": self.doubleField?.generableContent
                  ?? StructuredContent(kind: .null),
                "boolField": self.boolField?.generableContent
                  ?? StructuredContent(kind: .null),
                "optionalString": self.optionalString?.generableContent
                  ?? StructuredContent(kind: .null),
                "optionalInt": self.optionalInt?.generableContent
                  ?? StructuredContent(kind: .null),
                "arrayOfStrings": self.arrayOfStrings?.generableContent
                  ?? StructuredContent(kind: .null),
                "arrayOfInts": self.arrayOfInts?.generableContent
                  ?? StructuredContent(kind: .null),
                "optionalArrayOfBools": self.optionalArrayOfBools?.generableContent
                  ?? StructuredContent(kind: .null),
                "customType": self.customType?.generableContent
                  ?? StructuredContent(kind: .null),
                "arrayOfCustomTypes": self.arrayOfCustomTypes?.generableContent
                  ?? StructuredContent(kind: .null),
                "optionalArrayOfCustomTypes": self.optionalArrayOfCustomTypes?
                  .generableContent ?? StructuredContent(kind: .null),
              ])
            )
          }

          public nonisolated init(from structuredContent: StructuredContent) throws {
            let object = try structuredContent.object

            if let stringFieldContent = object["stringField"] {
              self.stringField = try String.Partial?(from: stringFieldContent)
            }
            else {
              self.stringField = nil
            }

            if let intFieldContent = object["intField"] {
              self.intField = try Int.Partial?(from: intFieldContent)
            }
            else {
              self.intField = nil
            }

            if let doubleFieldContent = object["doubleField"] {
              self.doubleField = try Double.Partial?(from: doubleFieldContent)
            }
            else {
              self.doubleField = nil
            }

            if let boolFieldContent = object["boolField"] {
              self.boolField = try Bool.Partial?(from: boolFieldContent)
            }
            else {
              self.boolField = nil
            }

            if let optionalStringContent = object["optionalString"] {
              self.optionalString = try String.Partial?(from: optionalStringContent)
            }
            else {
              self.optionalString = nil
            }

            if let optionalIntContent = object["optionalInt"] {
              self.optionalInt = try Int.Partial?(from: optionalIntContent)
            }
            else {
              self.optionalInt = nil
            }

            if let arrayOfStringsContent = object["arrayOfStrings"] {
              self.arrayOfStrings = try [String].Partial?(from: arrayOfStringsContent)
            }
            else {
              self.arrayOfStrings = nil
            }

            if let arrayOfIntsContent = object["arrayOfInts"] {
              self.arrayOfInts = try [Int].Partial?(from: arrayOfIntsContent)
            }
            else {
              self.arrayOfInts = nil
            }

            if let optionalArrayOfBoolsContent = object["optionalArrayOfBools"] {
              self.optionalArrayOfBools = try [Bool].Partial?(
                from: optionalArrayOfBoolsContent
              )
            }
            else {
              self.optionalArrayOfBools = nil
            }

            if let customTypeContent = object["customType"] {
              self.customType = try CustomStruct.Partial?(from: customTypeContent)
            }
            else {
              self.customType = nil
            }

            if let arrayOfCustomTypesContent = object["arrayOfCustomTypes"] {
              self.arrayOfCustomTypes = try [CustomStruct].Partial?(
                from: arrayOfCustomTypesContent
              )
            }
            else {
              self.arrayOfCustomTypes = nil
            }

            if let optionalArrayOfCustomTypesContent = object[
              "optionalArrayOfCustomTypes"
            ] {
              self.optionalArrayOfCustomTypes = try [CustomStruct].Partial?(
                from: optionalArrayOfCustomTypesContent
              )
            }
            else {
              self.optionalArrayOfCustomTypes = nil
            }
          }
        }

        public nonisolated static var schema: Schema {
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
              "arrayOfCustomTypes": Schema.Property(
                schema: [CustomStruct].schema,
                description: nil,
                isOptional: false
              ),
              "optionalArrayOfCustomTypes": Schema.Property(
                schema: [CustomStruct].schema,
                description: nil,
                isOptional: true
              ),
            ]
          )
        }

        public nonisolated var generableContent: StructuredContent {
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
              "arrayOfCustomTypes": self.arrayOfCustomTypes.generableContent,
              "optionalArrayOfCustomTypes": self.optionalArrayOfCustomTypes?
                .generableContent ?? StructuredContent(kind: .null),
            ])
          )
        }

        public nonisolated init(from structuredContent: StructuredContent) throws {
          let object = try structuredContent.object

          guard let stringFieldContent = object["stringField"] else {
            throw LLMError.generalError("Missing required property: stringField")
          }
          self.stringField = try String(from: stringFieldContent)

          guard let intFieldContent = object["intField"] else {
            throw LLMError.generalError("Missing required property: intField")
          }
          self.intField = try Int(from: intFieldContent)

          guard let doubleFieldContent = object["doubleField"] else {
            throw LLMError.generalError("Missing required property: doubleField")
          }
          self.doubleField = try Double(from: doubleFieldContent)

          guard let boolFieldContent = object["boolField"] else {
            throw LLMError.generalError("Missing required property: boolField")
          }
          self.boolField = try Bool(from: boolFieldContent)

          if let optionalStringContent = object["optionalString"] {
            self.optionalString = try String?(from: optionalStringContent)
          }
          else {
            self.optionalString = nil
          }

          if let optionalIntContent = object["optionalInt"] {
            self.optionalInt = try Int?(from: optionalIntContent)
          }
          else {
            self.optionalInt = nil
          }

          guard let arrayOfStringsContent = object["arrayOfStrings"] else {
            throw LLMError.generalError("Missing required property: arrayOfStrings")
          }
          self.arrayOfStrings = try [String] (from: arrayOfStringsContent)

          guard let arrayOfIntsContent = object["arrayOfInts"] else {
            throw LLMError.generalError("Missing required property: arrayOfInts")
          }
          self.arrayOfInts = try [Int] (from: arrayOfIntsContent)

          if let optionalArrayOfBoolsContent = object["optionalArrayOfBools"] {
            self.optionalArrayOfBools = try [Bool]?(from: optionalArrayOfBoolsContent)
          }
          else {
            self.optionalArrayOfBools = nil
          }

          guard let customTypeContent = object["customType"] else {
            throw LLMError.generalError("Missing required property: customType")
          }
          self.customType = try CustomStruct(from: customTypeContent)

          guard let arrayOfCustomTypesContent = object["arrayOfCustomTypes"] else {
            throw LLMError.generalError(
              "Missing required property: arrayOfCustomTypes"
            )
          }
          self.arrayOfCustomTypes = try [CustomStruct] (
            from: arrayOfCustomTypesContent
          )

          if let optionalArrayOfCustomTypesContent = object[
            "optionalArrayOfCustomTypes"
          ] {
            self.optionalArrayOfCustomTypes = try [CustomStruct]?(
              from: optionalArrayOfCustomTypesContent
            )
          }
          else {
            self.optionalArrayOfCustomTypes = nil
          }
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

      nonisolated extension User: SwiftAI.Generable {
        public nonisolated struct Partial: SwiftAI.GenerableContentConvertible,
          Sendable
        {
          public let name: String.Partial?

          public nonisolated var generableContent: StructuredContent {
            StructuredContent(
              kind: .object([
                "name": self.name?.generableContent ?? StructuredContent(kind: .null)
              ])
            )
          }

          public nonisolated init(from structuredContent: StructuredContent) throws {
            let object = try structuredContent.object

            if let nameContent = object["name"] {
              self.name = try String.Partial?(from: nameContent)
            }
            else {
              self.name = nil
            }
          }
        }

        public nonisolated static var schema: Schema {
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

        public nonisolated var generableContent: StructuredContent {
          StructuredContent(kind: .object(["name": self.name.generableContent]))
        }

        public nonisolated init(from structuredContent: StructuredContent) throws {
          let object = try structuredContent.object

          guard let nameContent = object["name"] else {
            throw LLMError.generalError("Missing required property: name")
          }
          self.name = try String(from: nameContent)
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

      nonisolated extension ConstrainedFields: SwiftAI.Generable {
        public nonisolated struct Partial: SwiftAI.GenerableContentConvertible,
          Sendable
        {
          public let name: String.Partial?
          public let age: Int.Partial?
          public let score: Double.Partial?
          public let tags: [String].Partial?

          public nonisolated var generableContent: StructuredContent {
            StructuredContent(
              kind: .object([
                "name": self.name?.generableContent ?? StructuredContent(kind: .null),
                "age": self.age?.generableContent ?? StructuredContent(kind: .null),
                "score": self.score?.generableContent
                  ?? StructuredContent(kind: .null),
                "tags": self.tags?.generableContent ?? StructuredContent(kind: .null),
              ])
            )
          }

          public nonisolated init(from structuredContent: StructuredContent) throws {
            let object = try structuredContent.object

            if let nameContent = object["name"] {
              self.name = try String.Partial?(from: nameContent)
            }
            else {
              self.name = nil
            }

            if let ageContent = object["age"] {
              self.age = try Int.Partial?(from: ageContent)
            }
            else {
              self.age = nil
            }

            if let scoreContent = object["score"] {
              self.score = try Double.Partial?(from: scoreContent)
            }
            else {
              self.score = nil
            }

            if let tagsContent = object["tags"] {
              self.tags = try [String].Partial?(from: tagsContent)
            }
            else {
              self.tags = nil
            }
          }
        }

        public nonisolated static var schema: Schema {
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

        public nonisolated var generableContent: StructuredContent {
          StructuredContent(
            kind: .object([
              "name": self.name.generableContent, "age": self.age.generableContent,
              "score": self.score?.generableContent ?? StructuredContent(kind: .null),
              "tags": self.tags.generableContent,
            ])
          )
        }

        public nonisolated init(from structuredContent: StructuredContent) throws {
          let object = try structuredContent.object

          guard let nameContent = object["name"] else {
            throw LLMError.generalError("Missing required property: name")
          }
          self.name = try String(from: nameContent)

          guard let ageContent = object["age"] else {
            throw LLMError.generalError("Missing required property: age")
          }
          self.age = try Int(from: ageContent)

          if let scoreContent = object["score"] {
            self.score = try Double?(from: scoreContent)
          }
          else {
            self.score = nil
          }

          guard let tagsContent = object["tags"] else {
            throw LLMError.generalError("Missing required property: tags")
          }
          self.tags = try [String] (from: tagsContent)
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

      nonisolated extension ExplicitConstraintFields: SwiftAI.Generable {
        public nonisolated struct Partial: SwiftAI.GenerableContentConvertible,
          Sendable
        {
          public let name: String.Partial?
          public let age: Int.Partial?
          public let score: Double.Partial?
          public let tags: [String].Partial?

          public nonisolated var generableContent: StructuredContent {
            StructuredContent(
              kind: .object([
                "name": self.name?.generableContent ?? StructuredContent(kind: .null),
                "age": self.age?.generableContent ?? StructuredContent(kind: .null),
                "score": self.score?.generableContent
                  ?? StructuredContent(kind: .null),
                "tags": self.tags?.generableContent ?? StructuredContent(kind: .null),
              ])
            )
          }

          public nonisolated init(from structuredContent: StructuredContent) throws {
            let object = try structuredContent.object

            if let nameContent = object["name"] {
              self.name = try String.Partial?(from: nameContent)
            }
            else {
              self.name = nil
            }

            if let ageContent = object["age"] {
              self.age = try Int.Partial?(from: ageContent)
            }
            else {
              self.age = nil
            }

            if let scoreContent = object["score"] {
              self.score = try Double.Partial?(from: scoreContent)
            }
            else {
              self.score = nil
            }

            if let tagsContent = object["tags"] {
              self.tags = try [String].Partial?(from: tagsContent)
            }
            else {
              self.tags = nil
            }
          }
        }

        public nonisolated static var schema: Schema {
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

        public nonisolated var generableContent: StructuredContent {
          StructuredContent(
            kind: .object([
              "name": self.name.generableContent, "age": self.age.generableContent,
              "score": self.score?.generableContent ?? StructuredContent(kind: .null),
              "tags": self.tags.generableContent,
            ])
          )
        }

        public nonisolated init(from structuredContent: StructuredContent) throws {
          let object = try structuredContent.object

          guard let nameContent = object["name"] else {
            throw LLMError.generalError("Missing required property: name")
          }
          self.name = try String(from: nameContent)

          guard let ageContent = object["age"] else {
            throw LLMError.generalError("Missing required property: age")
          }
          self.age = try Int(from: ageContent)

          if let scoreContent = object["score"] {
            self.score = try Double?(from: scoreContent)
          }
          else {
            self.score = nil
          }

          guard let tagsContent = object["tags"] else {
            throw LLMError.generalError("Missing required property: tags")
          }
          self.tags = try [String] (from: tagsContent)
        }
      }
      """
    }
  }

  @Test
  func testGenerableRejectsClass() throws {
    assertMacro {
      """
      @Generable
      class InvalidClass {
        let name: String
        let age: Int
      }
      """
    } diagnostics: {
      """
      @Generable
      ┬─────────
      ╰─ 🛑 @Generable can only be applied to structs or enums
      class InvalidClass {
        let name: String
        let age: Int
      }
      """
    }
  }

  @Test
  func testSimpleEnum() throws {
    assertMacro(indentationWidth: .spaces(2)) {
      """
      @Generable
      enum Status {
        case active
        case inactive
        case pending
      }
      """
    } expansion: {
      #"""
      enum Status {
        case active
        case inactive
        case pending
      }

      nonisolated extension Status: SwiftAI.Generable {
        public typealias Partial = Self

        public nonisolated static var schema: Schema {
          .anyOf(
            name: "Status",
            description: nil,
            schemas: [
              .string(constraints: [.constant("active")]),
              .string(constraints: [.constant("inactive")]),
              .string(constraints: [.constant("pending")]),
            ]
          )
        }

        public nonisolated var generableContent: StructuredContent {
          switch self {
          case .active:
            return StructuredContent(kind: .string("active"))
          case .inactive:
            return StructuredContent(kind: .string("inactive"))
          case .pending:
            return StructuredContent(kind: .string("pending"))
          }
        }

        public nonisolated init(from structuredContent: StructuredContent) throws {
          let stringValue = try structuredContent.string
          switch stringValue {
          case "active":
            self = .active
          case "inactive":
            self = .inactive
          case "pending":
            self = .pending
          default:
            throw LLMError.generalError("Unknown enum case: \(stringValue)")
          }
        }
      }
      """#
    }
  }

  @Test
  func testEnumWithAssociatedValues_ThrowsError() throws {
    assertMacro(indentationWidth: .spaces(2)) {
      """
      @Generable
      enum Result {
        case success(String)
        case failure(Error)
      }
      """
    } diagnostics: {
      """
      @Generable
      ┬─────────
      ╰─ 🛑 Enums with associated values are not yet supported
      enum Result {
        case success(String)
        case failure(Error)
      }
      """
    }
  }

  @Test
  func testStructWithEnumProperty() throws {
    assertMacro(indentationWidth: .spaces(2)) {
      """
      @Generable
      struct Task {
        let title: String
        let status: Status
      }
      """
    } expansion: {
      """
      struct Task {
        let title: String
        let status: Status
      }

      nonisolated extension Task: SwiftAI.Generable {
        public nonisolated struct Partial: SwiftAI.GenerableContentConvertible,
          Sendable
        {
          public let title: String.Partial?
          public let status: Status.Partial?

          public nonisolated var generableContent: StructuredContent {
            StructuredContent(
              kind: .object([
                "title": self.title?.generableContent
                  ?? StructuredContent(kind: .null),
                "status": self.status?.generableContent
                  ?? StructuredContent(kind: .null),
              ])
            )
          }

          public nonisolated init(from structuredContent: StructuredContent) throws {
            let object = try structuredContent.object

            if let titleContent = object["title"] {
              self.title = try String.Partial?(from: titleContent)
            }
            else {
              self.title = nil
            }

            if let statusContent = object["status"] {
              self.status = try Status.Partial?(from: statusContent)
            }
            else {
              self.status = nil
            }
          }
        }

        public nonisolated static var schema: Schema {
          .object(
            name: "Task",
            description: nil,
            properties: [
              "title": Schema.Property(
                schema: String.schema,
                description: nil,
                isOptional: false
              ),
              "status": Schema.Property(
                schema: Status.schema,
                description: nil,
                isOptional: false
              ),
            ]
          )
        }

        public nonisolated var generableContent: StructuredContent {
          StructuredContent(
            kind: .object([
              "title": self.title.generableContent,
              "status": self.status.generableContent,
            ])
          )
        }

        public nonisolated init(from structuredContent: StructuredContent) throws {
          let object = try structuredContent.object

          guard let titleContent = object["title"] else {
            throw LLMError.generalError("Missing required property: title")
          }
          self.title = try String(from: titleContent)

          guard let statusContent = object["status"] else {
            throw LLMError.generalError("Missing required property: status")
          }
          self.status = try Status(from: statusContent)
        }
      }
      """
    }
  }
}
