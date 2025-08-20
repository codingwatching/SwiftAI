import Testing

@testable import SwiftAI

@Suite
struct SchemaTests {
  @Test
  func testWithConstraint_AddPatternConstraint_ReturnsCorrectSchema() {
    let schema = Schema.string(constraints: [])
    let newSchema = schema.withConstraint(AnyConstraint(.pattern("abc")))
    #expect(newSchema == .string(constraints: [.pattern("abc")]))
  }

  @Test
  func testWithConstraint_AddMinimumConstraint_ReturnsCorrectSchema() {
    let schema = Schema.integer(constraints: [])
    let newSchema = schema.withConstraint(AnyConstraint(.minimum(10)))
    #expect(newSchema == .integer(constraints: [.range(lowerBound: 10, upperBound: nil)]))
  }

  @Test
  func testWithConstraint_AddMinimumCountConstraint_ReturnsCorrectSchema() {
    let schema = Schema.array(items: .string(constraints: []), constraints: [])
    let newSchema = schema.withConstraint(AnyConstraint(.minimumCount(1)))
    let expectedConstraint = AnyConstraint(.minimumCount(1))
    #expect(newSchema == .array(items: .string(constraints: []), constraints: [expectedConstraint]))
  }

  @Test
  func testWithConstraint_AddElementConstraint_ReturnsCorrectSchema() {
    let schema = Schema.array(items: .string(constraints: []), constraints: [])
    let constraint = AnyConstraint(Constraint<[String]>.element(Constraint<String>.pattern(".*")))
    let newSchema = schema.withConstraint(constraint)
    let expectedItems = Schema.string(constraints: [.pattern(".*")])
    #expect(newSchema == .array(items: expectedItems, constraints: []))
  }

  @Test
  func testWithConstraint_ArrayWithExistingConstraints_AddsNewConstraint() {
    let existingConstraints = [AnyConstraint(.minimumCount(1))]
    let schema = Schema.array(items: .string(constraints: []), constraints: existingConstraints)
    let newSchema = schema.withConstraint(AnyConstraint(.maximumCount(10)))
    let expectedConstraint = AnyConstraint(.maximumCount(10))
    #expect(
      newSchema
        == .array(
          items: .string(constraints: []), constraints: existingConstraints + [expectedConstraint]))
  }

  @Test
  func testWithConstraint_ArrayWithExistingElementConstraints_AddsNewElementConstraint() {
    let existingElementConstraints: [StringConstraint] = [.pattern("abc")]
    let schema = Schema.array(
      items: .string(constraints: existingElementConstraints), constraints: [])
    let newSchema = schema.withConstraint(
      AnyConstraint(Constraint<[String]>.element(Constraint<String>.constant("def"))))
    let expectedItems = Schema.string(
      constraints: existingElementConstraints + [.constant("def")])
    #expect(newSchema == .array(items: expectedItems, constraints: []))
  }

  @Test
  func testWithConstraints_AddMultipleConstraints_ReturnsCorrectSchema() {
    let schema = Schema.string(constraints: [])
    let constraints = [
      AnyConstraint(.pattern("abc")),
      AnyConstraint(.constant("def")),
      AnyConstraint(.anyOf(["ghi", "jkl"])),
    ]
    let newSchema = schema.withConstraints(constraints)
    let expectedConstraints: [StringConstraint] = [
      .pattern("abc"),
      .constant("def"),
      .anyOf(["ghi", "jkl"]),
    ]
    #expect(newSchema == .string(constraints: expectedConstraints))
  }

  @Test
  func testWithConstraints_ArrayWithMultipleConstraints_ReturnsCorrectSchema() {
    let schema = Schema.array(items: .string(constraints: []), constraints: [])
    let constraints = [
      AnyConstraint(.minimumCount(1)),
      AnyConstraint(.maximumCount(10)),
      AnyConstraint(Constraint<[String]>.element(Constraint<String>.pattern(".*"))),
    ]
    let newSchema = schema.withConstraints(constraints)
    let expectedArrayConstraints = [
      AnyConstraint(.minimumCount(1)),
      AnyConstraint(.maximumCount(10)),
    ]
    let expectedItems = Schema.string(constraints: [.pattern(".*")])
    #expect(newSchema == .array(items: expectedItems, constraints: expectedArrayConstraints))
  }

  @Test
  func testWithConstraint_SchemaAlreadyHasConstraints_AppendsNewConstraint() {
    let existingConstraints: [StringConstraint] = [.pattern("abc"), .constant("def")]
    let schema = Schema.string(constraints: existingConstraints)
    let newSchema = schema.withConstraint(AnyConstraint(.anyOf(["ghi", "jkl"])))
    let expectedConstraints = existingConstraints + [.anyOf(["ghi", "jkl"])]
    #expect(newSchema == .string(constraints: expectedConstraints))
  }

  @Test
  func testWithConstraint_IntegerWithExistingConstraints_AppendsNewConstraint() {
    let existingConstraints: [IntConstraint] = [.range(lowerBound: 1, upperBound: nil), .range(lowerBound: nil, upperBound: 100)]
    let schema = Schema.integer(constraints: existingConstraints)
    let newSchema = schema.withConstraint(AnyConstraint(.range(5...50)))
    let expectedConstraints = existingConstraints + [.range(lowerBound: 5, upperBound: 50)]
    #expect(newSchema == .integer(constraints: expectedConstraints))
  }
}
