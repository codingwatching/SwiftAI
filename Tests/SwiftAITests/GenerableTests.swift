import Testing

@testable import SwiftAI

@Suite
struct GenerableTests {

  @Test
  func testGenerableContent_WithAllPrimitives_ReturnsCorrectContent() throws {
    let testStruct = PrimitivesStruct(
      stringField: "test",
      intField: 42,
      doubleField: 3.14,
      boolField: true
    )

    let content = testStruct.generableContent

    let expected = StructuredContent(
      kind: .object([
        "stringField": StructuredContent(kind: .string("test")),
        "intField": StructuredContent(kind: .number(Double(42))),
        "doubleField": StructuredContent(kind: .number(3.14)),
        "boolField": StructuredContent(kind: .bool(true)),
      ]))

    #expect(content == expected)
  }

  @Test
  func testGenerableContent_WithOptionalProperties_ReturnsCorrectContent() throws {
    // Test with all values set
    let testStructWithValues = OptionalsStruct(
      optionalString: "test",
      optionalInt: 42,
      optionalDouble: 3.14,
      optionalBool: true
    )

    let contentWithValues = testStructWithValues.generableContent

    let expectedWithValues = StructuredContent(
      kind: .object([
        "optionalString": StructuredContent(kind: .string("test")),
        "optionalInt": StructuredContent(kind: .number(Double(42))),
        "optionalDouble": StructuredContent(kind: .number(3.14)),
        "optionalBool": StructuredContent(kind: .bool(true)),
      ]))

    #expect(contentWithValues == expectedWithValues)

    // Test with all values nil
    let testStructWithNils = OptionalsStruct(
      optionalString: nil,
      optionalInt: nil,
      optionalDouble: nil,
      optionalBool: nil
    )

    let contentWithNils = testStructWithNils.generableContent

    let expectedWithNils = StructuredContent(
      kind: .object([
        "optionalString": StructuredContent(kind: .null),
        "optionalInt": StructuredContent(kind: .null),
        "optionalDouble": StructuredContent(kind: .null),
        "optionalBool": StructuredContent(kind: .null),
      ]))

    #expect(contentWithNils == expectedWithNils)
  }

  @Test
  func testGenerableContent_WithArrayProperties_ReturnsCorrectContent() throws {
    let testStruct = ArraysStruct(
      stringArray: ["tag1", "tag2"],
      intArray: [1, 2, 3],
      boolArray: [true, false]
    )

    let content = testStruct.generableContent

    let expected = StructuredContent(
      kind: .object([
        "stringArray": StructuredContent(
          kind: .array([
            StructuredContent(kind: .string("tag1")),
            StructuredContent(kind: .string("tag2")),
          ])),
        "intArray": StructuredContent(
          kind: .array([
            StructuredContent(kind: .number(Double(1))),
            StructuredContent(kind: .number(Double(2))),
            StructuredContent(kind: .number(Double(3))),
          ])),
        "boolArray": StructuredContent(
          kind: .array([
            StructuredContent(kind: .bool(true)),
            StructuredContent(kind: .bool(false)),
          ])),
      ]))

    #expect(content == expected)
  }

  @Test
  func testGenerableContent_WithNestedObjects_ReturnsCorrectContent() throws {
    let nestedStruct = PrimitivesStruct(
      stringField: "nested",
      intField: 100,
      doubleField: 2.718,
      boolField: false
    )

    let testStruct = NestedStruct(
      name: "parent",
      nested: nestedStruct
    )

    let content = testStruct.generableContent

    let expected = StructuredContent(
      kind: .object([
        "name": StructuredContent(kind: .string("parent")),
        "nested": StructuredContent(
          kind: .object([
            "stringField": StructuredContent(kind: .string("nested")),
            "intField": StructuredContent(kind: .number(Double(100))),
            "doubleField": StructuredContent(kind: .number(2.718)),
            "boolField": StructuredContent(kind: .bool(false)),
          ])),
      ]))

    #expect(content == expected)
  }

  @Test("String initializes from StructuredContent")
  func testString_InitFromStructuredContent_Succeeds() throws {
    let content = StructuredContent(kind: .string("hello"))
    let value = try String(from: content)
    #expect(value == "hello")
  }

  @Test("Int initializes from StructuredContent with integer number")
  func testInt_InitFromStructuredContent_Succeeds() throws {
    let content = StructuredContent(kind: .number(42.0))
    let value = try Int(from: content)
    #expect(value == 42)
  }

  @Test("Int throws when initializing from non-integer number")
  func testInt_InitFromNonIntegerNumber_Throws() {
    let content = StructuredContent(kind: .number(3.14))
    #expect(throws: StructuredContentError.self) { try Int(from: content) }
  }

  @Test("Double initializes from StructuredContent")
  func testDouble_InitFromStructuredContent_Succeeds() throws {
    let content = StructuredContent(kind: .number(3.14))
    let value = try Double(from: content)
    #expect(value == 3.14)
  }

  @Test("Bool initializes from StructuredContent")
  func testBool_InitFromStructuredContent_Succeeds() throws {
    let trueContent = StructuredContent(kind: .bool(true))
    let trueValue = try Bool(from: trueContent)
    #expect(trueValue == true)

    let falseContent = StructuredContent(kind: .bool(false))
    let falseValue = try Bool(from: falseContent)
    #expect(falseValue == false)
  }

  @Test("Array initializes from StructuredContent with homogeneous elements")
  func testArray_InitFromStructuredContent_Succeeds() throws {
    let content = StructuredContent(
      kind: .array([
        StructuredContent(kind: .number(1.0)),
        StructuredContent(kind: .number(2.0)),
        StructuredContent(kind: .number(3.0)),
      ]))

    let array = try [Int](from: content)
    #expect(array == [1, 2, 3])
  }

  @Test("Array of strings initializes from StructuredContent")
  func testArrayOfStrings_InitFromStructuredContent_Succeeds() throws {
    let content = StructuredContent(
      kind: .array([
        StructuredContent(kind: .string("a")),
        StructuredContent(kind: .string("b")),
        StructuredContent(kind: .string("c")),
      ]))

    let array = try [String](from: content)
    #expect(array == ["a", "b", "c"])
  }

  @Test("Empty array initializes from StructuredContent")
  func testEmptyArray_InitFromStructuredContent_Succeeds() throws {
    let content = StructuredContent(kind: .array([]))
    let array = try [String](from: content)
    #expect(array.isEmpty)
  }

  @Test("Primitive types throw when initialized from wrong kind")
  func testPrimitives_InitFromWrongKind_Throws() {
    // String from non-string
    let numberContent = StructuredContent(kind: .number(42.0))
    #expect(throws: StructuredContentError.self) { try String(from: numberContent) }

    // Int from non-number
    let stringContent = StructuredContent(kind: .string("42"))
    #expect(throws: StructuredContentError.self) { try Int(from: stringContent) }

    // Bool from non-bool
    #expect(throws: StructuredContentError.self) { try Bool(from: numberContent) }

    // Array from non-array
    let objectContent = StructuredContent(kind: .object([:]))
    #expect(throws: StructuredContentError.self) { try [Int](from: objectContent) }
  }

  @Test("Struct with all primitives initializes from StructuredContent")
  func testStruct_AllPrimitives_InitFromStructuredContent() throws {
    let content = StructuredContent(
      kind: .object([
        "stringField": StructuredContent(kind: .string("Alice")),
        "intField": StructuredContent(kind: .number(30.0)),
        "doubleField": StructuredContent(kind: .number(95.5)),
        "boolField": StructuredContent(kind: .bool(true)),
      ]))

    let result = try PrimitivesStruct(from: content)
    #expect(result.stringField == "Alice")
    #expect(result.intField == 30)
    #expect(result.doubleField == 95.5)
    #expect(result.boolField == true)
  }

  @Test("Struct with optional properties initializes from StructuredContent")
  func testStruct_OptionalProperties_InitFromStructuredContent() throws {
    // All properties present
    let contentWithAll = StructuredContent(
      kind: .object([
        "optionalString": StructuredContent(kind: .string("Ali")),
        "optionalInt": StructuredContent(kind: .number(42.0)),
        "optionalDouble": StructuredContent(kind: .number(3.14)),
        "optionalBool": StructuredContent(kind: .bool(true)),
      ]))

    let resultWithAll = try OptionalsStruct(from: contentWithAll)
    #expect(resultWithAll.optionalString == "Ali")
    #expect(resultWithAll.optionalInt == 42)

    // Some properties null
    let contentWithNull = StructuredContent(
      kind: .object([
        "optionalString": StructuredContent(kind: .string("Ali")),
        "optionalInt": StructuredContent(kind: .null),
        "optionalDouble": StructuredContent(kind: .null),
        "optionalBool": StructuredContent(kind: .null),
      ]))

    let resultWithNull = try OptionalsStruct(from: contentWithNull)
    #expect(resultWithNull.optionalString == "Ali")
    #expect(resultWithNull.optionalInt == nil)
  }

  @Test("Struct with arrays initializes from StructuredContent")
  func testStruct_Arrays_InitFromStructuredContent() throws {
    let content = StructuredContent(
      kind: .object([
        "stringArray": StructuredContent(
          kind: .array([
            StructuredContent(kind: .string("swift")),
            StructuredContent(kind: .string("ai")),
          ])),
        "intArray": StructuredContent(
          kind: .array([
            StructuredContent(kind: .number(90.0)),
            StructuredContent(kind: .number(85.0)),
          ])),
        "boolArray": StructuredContent(
          kind: .array([
            StructuredContent(kind: .bool(true)),
            StructuredContent(kind: .bool(false)),
          ])),
      ]))

    let result = try ArraysStruct(from: content)
    #expect(result.stringArray == ["swift", "ai"])
    #expect(result.intArray == [90, 85])
  }

  @Test("Nested struct initializes from StructuredContent")
  func testStruct_Nested_InitFromStructuredContent() throws {
    let content = StructuredContent(
      kind: .object([
        "name": StructuredContent(kind: .string("Container")),
        "nested": StructuredContent(
          kind: .object([
            "stringField": StructuredContent(kind: .string("Alice")),
            "intField": StructuredContent(kind: .number(30.0)),
            "doubleField": StructuredContent(kind: .number(95.5)),
            "boolField": StructuredContent(kind: .bool(true)),
          ])),
      ]))

    let result = try NestedStruct(from: content)
    #expect(result.name == "Container")
    #expect(result.nested.stringField == "Alice")
    #expect(result.nested.intField == 30)
    #expect(result.nested.doubleField == 95.5)
    #expect(result.nested.boolField == true)
  }

  @Test("Init throws when required property is missing")
  func testStruct_MissingRequiredProperty_Throws() {
    let content = StructuredContent(
      kind: .object([
        // Missing "stringField"
        "intField": StructuredContent(kind: .number(30.0)),
        "doubleField": StructuredContent(kind: .number(95.5)),
        "boolField": StructuredContent(kind: .bool(true)),
      ]))

    #expect(throws: LLMError.self) { try PrimitivesStruct(from: content) }
  }

  @Test("Init throws when property has wrong type")
  func testStruct_WrongPropertyType_Throws() {
    let content = StructuredContent(
      kind: .object([
        "stringField": StructuredContent(kind: .number(42.0)),  // Wrong type: should be string
        "intField": StructuredContent(kind: .number(30.0)),
        "doubleField": StructuredContent(kind: .number(95.5)),
        "boolField": StructuredContent(kind: .bool(true)),
      ]))

    #expect(throws: Error.self) { try PrimitivesStruct(from: content) }
  }
}

// MARK: - Test Structs

@Generable
private struct PrimitivesStruct {
  let stringField: String
  let intField: Int
  let doubleField: Double
  let boolField: Bool
}

@Generable
private struct OptionalsStruct {
  let optionalString: String?
  let optionalInt: Int?
  let optionalDouble: Double?
  let optionalBool: Bool?
}

@Generable
private struct ArraysStruct {
  let stringArray: [String]
  let intArray: [Int]
  let boolArray: [Bool]
}

@Generable
private struct NestedStruct {
  let name: String
  let nested: PrimitivesStruct
}
