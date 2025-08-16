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
        "intField": StructuredContent(kind: .integer(42)),
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
        "optionalInt": StructuredContent(kind: .integer(42)),
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
            StructuredContent(kind: .integer(1)),
            StructuredContent(kind: .integer(2)),
            StructuredContent(kind: .integer(3)),
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
            "intField": StructuredContent(kind: .integer(100)),
            "doubleField": StructuredContent(kind: .number(2.718)),
            "boolField": StructuredContent(kind: .bool(false)),
          ])),
      ]))

    #expect(content == expected)
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
