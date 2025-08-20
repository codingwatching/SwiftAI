import Testing

@testable import SwiftAI

@Suite
struct SchemaTests {
  @Test
  func testWithConstraint_AddPatternConstraint_ReturnsCorrectSchema() {
    let schema = Schema.string(constraints: [])
    let newSchema = schema.withConstraint(.pattern("abc"))
    #expect(newSchema == .string(constraints: [.pattern("abc")]))
  }

  @Test
  func testWithConstraint_AddMinimumConstraint_ReturnsCorrectSchema() {
    let schema = Schema.integer(constraints: [])
    let newSchema = schema.withConstraint(.minimum(10))
    #expect(newSchema == .integer(constraints: [.range(lowerBound: 10, upperBound: nil)]))
  }

  @Test
  func testWithConstraint_AddMinimumCountConstraint_ReturnsCorrectSchema() {
    let schema = Schema.array(items: .string(constraints: []), constraints: [])
    let newSchema = schema.withConstraint(.minimumCount(1))
    let expectedConstraint = ArrayConstraint.count(lowerBound: 1, upperBound: nil)
    #expect(newSchema == .array(items: .string(constraints: []), constraints: [expectedConstraint]))
  }

  @Test
  func testWithConstraint_AddElementConstraint_ReturnsCorrectSchema() {
    let schema = Schema.array(items: .string(constraints: []), constraints: [])
    let constraint = Constraint<[String]>.element(.pattern(".*"))
    let newSchema = schema.withConstraint(constraint)
    let expectedItems = Schema.string(constraints: [.pattern(".*")])
    #expect(newSchema == .array(items: expectedItems, constraints: []))
  }

  @Test
  func testWithConstraint_ArrayWithExistingConstraints_AddsNewConstraint() {
    let existingConstraints = [ArrayConstraint.count(lowerBound: 1, upperBound: nil)]
    let schema = Schema.array(items: .string(constraints: []), constraints: existingConstraints)
    let newSchema = schema.withConstraint(.maximumCount(10))
    let expectedConstraint = ArrayConstraint.count(lowerBound: nil, upperBound: 10)
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
      Constraint<[String]>.element(.constant("def")))
    let expectedItems = Schema.string(
      constraints: existingElementConstraints + [.constant("def")])
    #expect(newSchema == .array(items: expectedItems, constraints: []))
  }

  @Test
  func testWithConstraints_AddMultipleConstraints_ReturnsCorrectSchema() {
    let schema = Schema.string(constraints: [])
    let constraints = [
      Constraint<String>.pattern("abc"),
      Constraint<String>.constant("def"),
      Constraint<String>.anyOf(["ghi", "jkl"]),
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
      Constraint<[String]>.minimumCount(1),
      Constraint<[String]>.maximumCount(10),
      Constraint<[String]>.element(.pattern(".*")),
    ]
    let newSchema = schema.withConstraints(constraints)
    let expectedArrayConstraints = [
      ArrayConstraint.count(lowerBound: 1, upperBound: nil),
      ArrayConstraint.count(lowerBound: nil, upperBound: 10),
    ]
    let expectedItems = Schema.string(constraints: [.pattern(".*")])
    #expect(newSchema == .array(items: expectedItems, constraints: expectedArrayConstraints))
  }

  @Test
  func testWithConstraint_SchemaAlreadyHasConstraints_AppendsNewConstraint() {
    let existingConstraints: [StringConstraint] = [.pattern("abc"), .constant("def")]
    let schema = Schema.string(constraints: existingConstraints)
    let newSchema = schema.withConstraint(.anyOf(["ghi", "jkl"]))
    let expectedConstraints = existingConstraints + [.anyOf(["ghi", "jkl"])]
    #expect(newSchema == .string(constraints: expectedConstraints))
  }

  @Test
  func testWithConstraint_IntegerWithExistingConstraints_AppendsNewConstraint() {
    let existingConstraints: [IntConstraint] = [.range(lowerBound: 1, upperBound: nil), .range(lowerBound: nil, upperBound: 100)]
    let schema = Schema.integer(constraints: existingConstraints)
    let newSchema = schema.withConstraint(.range(5...50))
    let expectedConstraints = existingConstraints + [.range(lowerBound: 5, upperBound: 50)]
    #expect(newSchema == .integer(constraints: expectedConstraints))
  }
}
