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
  func testGenerableContent_WithExplicitOptionalSyntax_AllValuesSet_ReturnsCorrectContent() throws {
    let testStruct = ExplicitOptionalStruct(
      optionalString: "hello",
      optionalInt: 42,
      optionalArray: ["a", "b", "c"]
    )

    let content = testStruct.generableContent

    let expected = StructuredContent(
      kind: .object([
        "optionalString": StructuredContent(kind: .string("hello")),
        "optionalInt": StructuredContent(kind: .number(Double(42))),
        "optionalArray": StructuredContent(
          kind: .array([
            StructuredContent(kind: .string("a")),
            StructuredContent(kind: .string("b")),
            StructuredContent(kind: .string("c")),
          ])),
      ]))

    #expect(content == expected)
  }

  @Test
  func testGenerableContent_WithExplicitOptionalSyntax_AllValuesNil_ReturnsCorrectContent() throws {
    let testStruct = ExplicitOptionalStruct(
      optionalString: nil,
      optionalInt: nil,
      optionalArray: nil
    )

    let content = testStruct.generableContent

    let expected = StructuredContent(
      kind: .object([
        "optionalString": StructuredContent(kind: .null),
        "optionalInt": StructuredContent(kind: .null),
        "optionalArray": StructuredContent(kind: .null),
      ]))

    #expect(content == expected)
  }

  @Test
  func testSchema_WithExplicitOptionalSyntax_ReturnsCorrectSchema() {
    let expected = Schema.object(
      name: "ExplicitOptionalStruct",
      description: nil,
      properties: [
        "optionalString": Schema.Property(
          schema: .optional(wrapped: String.schema),
          description: nil
        ),
        "optionalInt": Schema.Property(
          schema: .optional(wrapped: Int.schema),
          description: nil
        ),
        "optionalArray": Schema.Property(
          schema: .optional(wrapped: [String].schema),
          description: nil
        ),
      ]
    )

    #expect(ExplicitOptionalStruct.schema == expected)
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

  @Test
  func testEnum_Schema_IsAnyOf() {
    let want = Schema.anyOf(
      name: "Status",
      description: nil,
      schemas: [
        .string(constraints: [.constant("active")]),
        .string(constraints: [.constant("inactive")]),
        .string(constraints: [.constant("pending")]),
      ]
    )
    #expect(Status.schema == want)
  }

  @Test
  func testEnum_GenerableContent_ReturnsString() {
    let activeContent = Status.active.generableContent
    #expect(activeContent == StructuredContent(kind: .string("active")))

    let inactiveContent = Status.inactive.generableContent
    #expect(inactiveContent == StructuredContent(kind: .string("inactive")))

    let pendingContent = Status.pending.generableContent
    #expect(pendingContent == StructuredContent(kind: .string("pending")))
  }

  @Test
  func testEnum_InitFromStructuredContent_Succeeds() throws {
    let activeContent = StructuredContent(kind: .string("active"))
    let active = try Status(from: activeContent)
    #expect(active == .active)

    let pendingContent = StructuredContent(kind: .string("pending"))
    let pending = try Status(from: pendingContent)
    #expect(pending == .pending)
  }

  @Test
  func testEnum_InitFromInvalidString_Throws() {
    let content = StructuredContent(kind: .string("unknown"))
    #expect(throws: LLMError.self) { try Status(from: content) }
  }

  @Test
  func testEnum_InitFromWrongType_Throws() {
    let numberContent = StructuredContent(kind: .number(42.0))
    #expect(throws: Error.self) { try Status(from: numberContent) }

    let objectContent = StructuredContent(kind: .object([:]))
    #expect(throws: Error.self) { try Status(from: objectContent) }
  }

  @Test
  func testStructWithEnum_ReturnsCorrectGenerableContent() {
    let task = TaskWithEnum(title: "Fix bug", status: .active, priority: .high)
    let expected = StructuredContent(
      kind: .object([
        "title": .init(kind: .string("Fix bug")),
        "status": .init(kind: .string("active")),
        "priority": .init(kind: .string("high")),
      ])
    )
    #expect(task.generableContent == expected)
  }

  @Test
  func testStructWithEnum_InitFromStructuredContent() throws {
    let content = StructuredContent(
      kind: .object([
        "title": StructuredContent(kind: .string("Fix bug")),
        "status": StructuredContent(kind: .string("inactive")),
        "priority": StructuredContent(kind: .string("low")),
      ])
    )

    let task = try TaskWithEnum(from: content)
    #expect(task.title == "Fix bug")
    #expect(task.status == .inactive)
    #expect(task.priority == .low)
  }

  @Test
  func testStructWithOptionalEnum_InitFromStructuredContent_HandlesNilEnum() throws {
    let content = StructuredContent(
      kind: .object([
        "title": StructuredContent(kind: .string("Task")),
        "status": StructuredContent(kind: .null),
      ])
    )

    let task = try TaskWithOptionalEnum(from: content)
    #expect(task.title == "Task")
    #expect(task.status == nil)
  }

  @Test
  func testStructWithOptionalEnum_InitFromStructuredContent_HanledSetOptionalEnum() throws {
    let content = StructuredContent(
      kind: .object([
        "title": StructuredContent(kind: .string("Task")),
        "status": StructuredContent(kind: .string("pending")),
      ])
    )

    let task = try TaskWithOptionalEnum(from: content)
    #expect(task.title == "Task")
    #expect(task.status == .pending)
  }

  @Test
  func testEnum_RoundTripConvertion() throws {
    let originalStatus = Status.pending
    let content = originalStatus.generableContent
    let reconstructedStatus = try Status(from: content)
    #expect(reconstructedStatus == originalStatus)
  }

  @Test
  func testStructWithEnum_RoundTripConversion() throws {
    let original = TaskWithEnum(title: "Test", status: .active, priority: .medium)
    let content = original.generableContent
    let reconstructed = try TaskWithEnum(from: content)

    #expect(reconstructed.title == original.title)
    #expect(reconstructed.status == original.status)
    #expect(reconstructed.priority == original.priority)
  }

  // MARK: - Enums with Associated Values Tests

  // MARK: Schema Tests

  @Test
  func schemaForEnumWithLabeledAssociatedValues_ReturnsAnyOfWithObjectDiscriminators() {
    let want = Schema.anyOf(
      name: "Result",
      description: nil,
      schemas: [
        .object(
          name: "successDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("success")]),
              description: nil
            ),
            "value": Schema.Property(
              schema: String.schema,
              description: nil
            ),
          ]
        ),
        .object(
          name: "failureDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("failure")]),
              description: nil
            ),
            "error": Schema.Property(
              schema: String.schema,
              description: nil
            ),
          ]
        ),
      ]
    )
    #expect(Result.schema == want)
  }

  @Test
  func
    schemaForEnumWithMultipleLabeledAssociatedValues_ReturnsAnyOfWithAllPropertiesInObjectDiscriminators()
  {
    let want = Schema.anyOf(
      name: "Event",
      description: nil,
      schemas: [
        .object(
          name: "clickDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("click")]),
              description: nil
            ),
            "x": Schema.Property(
              schema: Int.schema,
              description: nil
            ),
            "y": Schema.Property(
              schema: Int.schema,
              description: nil
            ),
          ]
        ),
        .object(
          name: "scrollDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("scroll")]),
              description: nil
            ),
            "delta": Schema.Property(
              schema: Double.schema,
              description: nil
            ),
          ]
        ),
      ]
    )
    #expect(Event.schema == want)
  }

  @Test
  func schemaForMixedEnumWithSimpleAndAssociatedValueCases() {
    let want = Schema.anyOf(
      name: "MixedStatus",
      description: nil,
      schemas: [
        .object(
          name: "idleDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("idle")]),
              description: nil
            )
          ]
        ),
        .object(
          name: "loadingDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("loading")]),
              description: nil
            ),
            "message": Schema.Property(
              schema: String.schema,
              description: nil
            ),
          ]
        ),
        .object(
          name: "errorDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("error")]),
              description: nil
            ),
            "value": Schema.Property(
              schema: String.schema,
              description: nil
            ),
          ]
        ),
      ]
    )
    #expect(MixedStatus.schema == want)
  }

  // MARK: GenerableContent Tests

  @Test
  func
    generableContentForEnumWithLabeledAssociatedValue_ReturnsObjectWithTypeDiscriminatorAndValueProperty()
  {
    let result = Result.success(value: "OK")
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("success")),
        "value": StructuredContent(kind: .string("OK")),
      ])
    )
    #expect(result.generableContent == want)
  }

  @Test
  func
    generableContentForEnumWithMultipleLabeledAssociatedValues_ReturnsObjectWithTypeAndAllProperties()
  {
    let event = Event.click(x: 100, y: 200)
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("click")),
        "x": StructuredContent(kind: .number(100.0)),
        "y": StructuredContent(kind: .number(200.0)),
      ])
    )
    #expect(event.generableContent == want)
  }

  // 2. GenerableContent for associated values (unlabeled)
  @Test
  func generableContentForEnumWithUnlabeledAssociatedValue_ReturnsObjectWithValueKey() {
    let data = Data.text("hello")
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("text")),
        "value": StructuredContent(kind: .string("hello")),
      ])
    )
    #expect(data.generableContent == want)
  }

  @Test
  func
    generableContentForEnumWithMultipleUnlabeledAssociatedValues_ReturnsObjectWithIndexedValueKeys()
  {
    let data = Data.pair("key", 42)
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("pair")),
        "value": StructuredContent(kind: .string("key")),
        "value1": StructuredContent(kind: .number(42.0)),
      ])
    )
    #expect(data.generableContent == want)
  }

  @Test
  func generableContentForMixedEnumSimpleCase_ReturnsObjectWithTypeDiscriminatorOnly() {
    let status = MixedStatus.idle
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("idle"))
      ])
    )
    #expect(status.generableContent == want)
  }

  @Test
  func generableContentForMixedEnumAssociatedValueCase_ReturnsObjectWithTypeAndValueProperties() {
    let status = MixedStatus.loading(message: "Loading...")
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("loading")),
        "message": StructuredContent(kind: .string("Loading...")),
      ])
    )
    #expect(status.generableContent == want)
  }

  @Test
  func generableContentForStructContainingEnumWithAssociatedValues_ReturnsNestedObjectStructure() {
    let job = JobResult(title: "Deploy", result: .success(value: "Deployed v1.0"))
    let want = StructuredContent(
      kind: .object([
        "title": StructuredContent(kind: .string("Deploy")),
        "result": StructuredContent(
          kind: .object([
            "type": StructuredContent(kind: .string("success")),
            "value": StructuredContent(kind: .string("Deployed v1.0")),
          ])
        ),
      ])
    )
    #expect(job.generableContent == want)
  }

  @Test
  func generableContentForEnumWithOptionalAssociatedValue_WithNonNilValue_ReturnsObjectWithValue() {
    let data = OptionalData.withOptionalData(value: "test")
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("withOptionalData")),
        "value": StructuredContent(kind: .string("test")),
      ])
    )
    #expect(data.generableContent == want)
  }

  @Test
  func generableContentForEnumWithOptionalAssociatedValue_WithNilValue_ReturnsObjectWithNull() {
    let data = OptionalData.withOptionalData(value: nil)
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("withOptionalData")),
        "value": StructuredContent(kind: .null),
      ])
    )
    #expect(data.generableContent == want)
  }

  // MARK: Init from StructuredContent Tests

  @Test
  func initEnumWithLabeledAssociatedValue_FromObjectStructuredContent_SucceedsAndExtractsValue()
    throws
  {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("success")),
        "value": StructuredContent(kind: .string("OK")),
      ])
    )

    let result = try Result(from: content)
    let want = Result.success(value: "OK")
    #expect(result == want)
  }

  @Test
  func
    initEnumWithMultipleLabeledAssociatedValues_FromObjectStructuredContent_SucceedsAndExtractsAllValues()
    throws
  {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("click")),
        "x": StructuredContent(kind: .number(150.0)),
        "y": StructuredContent(kind: .number(250.0)),
      ])
    )

    let event = try Event(from: content)
    let want = Event.click(x: 150, y: 250)
    #expect(event == want)
  }

  // 3. Init from StructuredContent (success cases - unlabeled)
  @Test
  func
    initEnumWithUnlabeledAssociatedValue_FromObjectStructuredContent_SucceedsAndExtractsValueFromValueKey()
    throws
  {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("text")),
        "value": StructuredContent(kind: .string("test")),
      ])
    )

    let data = try Data(from: content)
    let want = Data.text("test")
    #expect(data == want)
  }

  @Test
  func
    initEnumWithMultipleUnlabeledAssociatedValues_FromObjectStructuredContent_SucceedsAndExtractsValuesFromIndexedKeys()
    throws
  {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("pair")),
        "value": StructuredContent(kind: .string("name")),
        "value1": StructuredContent(kind: .number(99.0)),
      ])
    )

    let data = try Data(from: content)
    let want = Data.pair("name", 99)
    #expect(data == want)
  }

  @Test
  func initMixedEnumSimpleCase_FromObjectWithTypeOnly_SucceedsAndReturnsCorrectCase() throws {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("idle"))
      ])
    )

    let status = try MixedStatus(from: content)
    #expect(status == .idle)
  }

  @Test
  func initMixedEnumAssociatedValueCase_FromObjectWithTypeAndValue_SucceedsAndExtractsValue() throws
  {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("error")),
        "value": StructuredContent(kind: .string("Failed")),
      ])
    )

    let status = try MixedStatus(from: content)
    let want = MixedStatus.error("Failed")
    #expect(status == want)
  }

  @Test
  func
    initStructContainingEnumWithAssociatedValues_FromNestedObjectStructuredContent_SucceedsAndExtractsValues()
    throws
  {
    let content = StructuredContent(
      kind: .object([
        "title": StructuredContent(kind: .string("Build")),
        "result": StructuredContent(
          kind: .object([
            "type": StructuredContent(kind: .string("failure")),
            "error": StructuredContent(kind: .string("Compilation failed")),
          ])
        ),
      ])
    )

    let job = try JobResult(from: content)
    let want = JobResult(title: "Build", result: .failure(error: "Compilation failed"))
    #expect(job == want)
  }

  @Test
  func initEnumWithOptionalAssociatedValue_FromObjectWithNonNullValue_SucceedsAndExtractsValue()
    throws
  {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("withOptionalData")),
        "value": StructuredContent(kind: .string("data")),
      ])
    )

    let data = try OptionalData(from: content)
    let want = OptionalData.withOptionalData(value: "data")
    #expect(data == want)
  }

  @Test
  func initEnumWithOptionalAssociatedValue_FromObjectWithNullValue_SucceedsAndExtractsNil() throws {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("withOptionalData")),
        "value": StructuredContent(kind: .null),
      ])
    )

    let data = try OptionalData(from: content)
    let want = OptionalData.withOptionalData(value: nil)
    #expect(data == want)
  }

  @Test
  func initEnumWithOptionalAssociatedValue_FromObjectMissingOptionalProperty_SucceedsWithNil()
    throws
  {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("withOptionalData"))
        // "value" is optional, so it's okay if missing
      ])
    )

    let data = try OptionalData(from: content)
    let want = OptionalData.withOptionalData(value: nil)
    #expect(data == want)
  }

  // MARK: Enum with Explicit Optional Syntax Tests

  @Test
  func schemaForEnumWithExplicitOptionalAssociatedValues_ReturnsAnyOfWithObjectDiscriminators() {
    let want = Schema.anyOf(
      name: "DataResult",
      description: nil,
      schemas: [
        .object(
          name: "dataDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("data")]),
              description: nil
            ),
            "value": Schema.Property(
              schema: .optional(wrapped: String.schema),
              description: nil
            ),
          ]
        ),
        .object(
          name: "errorDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("error")]),
              description: nil
            ),
            "code": Schema.Property(
              schema: .optional(wrapped: Int.schema),
              description: nil
            ),
          ]
        ),
        .object(
          name: "emptyDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("empty")]),
              description: nil
            )
          ]
        ),
      ]
    )
    #expect(DataResult.schema == want)
  }

  @Test
  func
    generableContentForEnum_WithExplicitOptionalAssociatedValue_WithNonNilValue_ReturnsObjectWithValue()
  {
    let data = DataResult.data(value: "test data")
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("data")),
        "value": StructuredContent(kind: .string("test data")),
      ])
    )
    #expect(data.generableContent == want)
  }

  @Test
  func
    generableContentForEnum_WithExplicitOptionalAssociatedValue_WithNilValue_ReturnsObjectWithNull()
  {
    let data = DataResult.data(value: nil)
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("data")),
        "value": StructuredContent(kind: .null),
      ])
    )
    #expect(data.generableContent == want)
  }

  @Test
  func
    initEnumWithExplicitOptionalAssociatedValue_FromObjectWithNonNilValue_SucceedsAndExtractsValue()
    throws
  {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("error")),
        "code": StructuredContent(kind: .number(404)),
      ])
    )

    let result = try DataResult(from: content)
    let want = DataResult.error(code: 404)
    #expect(result == want)
  }

  @Test
  func initEnumWithExplicitOptionalAssociatedValue_FromObjectWithNilValue_SucceedsAndExtractsNil()
    throws
  {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("data")),
        "value": StructuredContent(kind: .null),
      ])
    )

    let result = try DataResult(from: content)
    let want = DataResult.data(value: nil)
    #expect(result == want)
  }

  @Test
  func
    roundTripConversionForEnumWithExplicitOptionalAssociatedValue_WithNonNilValue_PreservesValue()
    throws
  {
    let original = DataResult.error(code: 500)
    let content = original.generableContent
    let reconstructed = try DataResult(from: content)
    #expect(reconstructed == original)
  }

  @Test
  func roundTripConversionForEnumWithExplicitOptionalAssociatedValue_WithNilValue_PreservesNil()
    throws
  {
    let original = DataResult.data(value: nil)
    let content = original.generableContent
    let reconstructed = try DataResult(from: content)
    #expect(reconstructed == original)
  }

  @Test
  func initEnumWithAssociatedValues_FromNonObjectStructuredContent_ThrowsError() {
    let stringContent = StructuredContent(kind: .string("success"))
    #expect(throws: Error.self) { try Result(from: stringContent) }

    let arrayContent = StructuredContent(kind: .array([]))
    #expect(throws: Error.self) { try Result(from: arrayContent) }
  }

  @Test
  func initEnumWithAssociatedValues_FromObjectMissingTypeDiscriminator_ThrowsLLMError() {
    let content = StructuredContent(
      kind: .object([
        "value": StructuredContent(kind: .string("OK"))
      ])
    )
    #expect(throws: LLMError.self) { try Result(from: content) }
  }

  @Test
  func initEnumWithAssociatedValues_FromObjectWithUnknownCaseType_ThrowsLLMError() {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("unknown")),
        "value": StructuredContent(kind: .string("test")),
      ])
    )
    #expect(throws: LLMError.self) { try Result(from: content) }
  }

  @Test
  func initEnumWithAssociatedValues_FromObjectMissingRequiredProperty_ThrowsLLMError() {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("success"))
        // Missing "value" property
      ])
    )
    #expect(throws: LLMError.self) { try Result(from: content) }
  }

  @Test
  func initEnumWithAssociatedValues_FromObjectWithWrongPropertyType_ThrowsError() {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("click")),
        "x": StructuredContent(kind: .string("not a number")),  // Wrong type
        "y": StructuredContent(kind: .number(100.0)),
      ])
    )
    #expect(throws: Error.self) { try Event(from: content) }
  }

  @Test
  func initEnumWithLabeledAssociatedValue_FromObjectWithMisspelledParameterName_ThrowsLLMError() {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("success")),
        "valu": StructuredContent(kind: .string("OK")),  // Misspelled: should be "value"
      ])
    )
    #expect(throws: LLMError.self) { try Result(from: content) }
  }

  @Test
  func initEnumWithMultipleLabeledAssociatedValues_FromObjectMissingOneParameter_ThrowsLLMError() {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("click")),
        "x": StructuredContent(kind: .number(100.0)),
        // Missing "y" parameter
      ])
    )
    #expect(throws: LLMError.self) { try Event(from: content) }
  }

  // MARK: Round-Trip Conversion Tests

  @Test
  func roundTripConversionForEnumWithLabeledAssociatedValue_PreservesValue() throws {
    let original = Result.failure(error: "Network error")
    let content = original.generableContent
    let reconstructed = try Result(from: content)
    #expect(reconstructed == original)
  }

  @Test
  func roundTripConversionForEnumWithMultipleLabeledAssociatedValues_PreservesAllValues() throws {
    let original = Event.scroll(delta: 42.5)
    let content = original.generableContent
    let reconstructed = try Event(from: content)
    #expect(reconstructed == original)
  }

  @Test
  func roundTripConversionForEnumWithUnlabeledAssociatedValue_PreservesValue() throws {
    let original = Data.number(777)
    let content = original.generableContent
    let reconstructed = try Data(from: content)
    #expect(reconstructed == original)
  }

  @Test
  func roundTripConversionForMixedEnumSimpleCase_PreservesCase() throws {
    let original = MixedStatus.idle
    let content = original.generableContent
    let reconstructed = try MixedStatus(from: content)
    #expect(reconstructed == original)
  }

  @Test
  func roundTripConversionForMixedEnumAssociatedValueCase_PreservesCaseAndValue() throws {
    let original = MixedStatus.loading(message: "Please wait")
    let content = original.generableContent
    let reconstructed = try MixedStatus(from: content)
    #expect(reconstructed == original)
  }

  @Test
  func roundTripConversionForStructContainingEnumWithAssociatedValues_PreservesAllValues() throws {
    let original = JobResult(title: "Test", result: .failure(error: "Tests failed"))
    let content = original.generableContent
    let reconstructed = try JobResult(from: content)
    #expect(reconstructed == original)
  }

  @Test
  func roundTripConversionForEnumWithOptionalAssociatedValue_WithNonNilValue_PreservesValue() throws
  {
    let original = OptionalData.withOptionalData(value: "hello")
    let content = original.generableContent
    let reconstructed = try OptionalData(from: content)
    #expect(reconstructed == original)
  }

  @Test
  func roundTripConversionForEnumWithOptionalAssociatedValue_WithNilValue_PreservesNil() throws {
    let original = OptionalData.withOptionalData(value: nil)
    let content = original.generableContent
    let reconstructed = try OptionalData(from: content)
    #expect(reconstructed == original)
  }

  // MARK: Comma-Separated Case Declarations Tests

  @Test
  func schemaForEnumWithCommaSeparatedCaseDeclarations_ReturnsAnyOfWithObjectDiscriminators() {
    let want = Schema.anyOf(
      name: "ApiResponse",
      description: "The API response status",
      schemas: [
        .object(
          name: "pendingDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("pending")]),
              description: nil
            )
          ]
        ),
        .object(
          name: "successDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("success")]),
              description: nil
            ),
            "data": Schema.Property(
              schema: String.schema,
              description: nil
            ),
          ]
        ),
        .object(
          name: "errorDiscriminator",
          description: nil,
          properties: [
            "type": Schema.Property(
              schema: .string(constraints: [.constant("error")]),
              description: nil
            ),
            "message": Schema.Property(
              schema: String.schema,
              description: nil
            ),
          ]
        ),
      ]
    )
    #expect(ApiResponse.schema == want)
  }

  @Test
  func generableContentForEnumWithCommaSeparatedCases_SimpleCaseReturnsObjectWithTypeOnly() {
    let response = ApiResponse.pending
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("pending"))
      ])
    )
    #expect(response.generableContent == want)
  }

  @Test
  func
    generableContentForEnumWithCommaSeparatedCases_AssociatedValueCaseReturnsObjectWithTypeAndProperties()
  {
    let response = ApiResponse.success(data: "test data")
    let want = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("success")),
        "data": StructuredContent(kind: .string("test data")),
      ])
    )
    #expect(response.generableContent == want)
  }

  @Test
  func initEnumWithCommaSeparatedCases_FromObjectWithSimpleCase_SucceedsAndReturnsCorrectCase()
    throws
  {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("pending"))
      ])
    )

    let response = try ApiResponse(from: content)
    #expect(response == .pending)
  }

  @Test
  func initEnumWithCommaSeparatedCases_FromObjectWithAssociatedValues_SucceedsAndExtractsValues()
    throws
  {
    let content = StructuredContent(
      kind: .object([
        "type": StructuredContent(kind: .string("error")),
        "message": StructuredContent(kind: .string("Not found")),
      ])
    )

    let response = try ApiResponse(from: content)
    let want = ApiResponse.error(message: "Not found")
    #expect(response == want)
  }

  @Test
  func roundTripConversionForEnumWithCommaSeparatedCases_PreservesAllValues() throws {
    let original = ApiResponse.success(data: "test")
    let content = original.generableContent
    let reconstructed = try ApiResponse(from: content)
    #expect(reconstructed == original)
  }

  // MARK: @Generable Description Parameter Tests

  @Test
  func testStructWithDescription_SchemaIncludesDescription() {
    let schema = NestedStruct.schema
    guard case .object(let name, let description, _) = schema else {
      Issue.record("Expected .object schema for NestedStruct")
      return
    }
    #expect(name == "NestedStruct")
    #expect(description == "A struct that contains another struct")
  }

  @Test
  func testEnumWithDescription_SchemaIncludesDescription() {
    let schema = ApiResponse.schema
    guard case .anyOf(let name, let description, _) = schema else {
      Issue.record("Expected .anyOf schema for ApiResponse")
      return
    }
    #expect(name == "ApiResponse")
    #expect(description == "The API response status")
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
private struct ExplicitOptionalStruct {
  let optionalString: String?
  let optionalInt: Swift.Optional<Int>
  let optionalArray: [String]?
}

@Generable
private struct ArraysStruct {
  let stringArray: [String]
  let intArray: [Int]
  let boolArray: [Bool]
}

@Generable(description: "A struct that contains another struct")
private struct NestedStruct {
  let name: String
  let nested: PrimitivesStruct
}

@Generable
private enum Status {
  case active
  case inactive
  case pending
}

@Generable
private enum Priority {
  case low
  case medium
  case high
}

@Generable
private struct TaskWithEnum {
  let title: String
  let status: Status
  let priority: Priority
}

@Generable
private struct TaskWithOptionalEnum {
  let title: String
  let status: Status?
}

// Enums with associated values for Phase 2 testing
@Generable
private enum Result: Equatable {
  case success(value: String)
  case failure(error: String)
}

@Generable
private enum Event: Equatable {
  case click(x: Int, y: Int)
  case scroll(delta: Double)
}

@Generable
private enum Data: Equatable {
  case text(String)
  case number(Int)
  case pair(String, Int)
}

@Generable
private enum MixedStatus: Equatable {
  case idle
  case loading(message: String)
  case error(String)
}

@Generable
private enum OptionalData: Equatable {
  case withOptionalData(value: String?)
  case noData
}

@Generable
private struct JobResult: Equatable {
  let title: String
  let result: Result
}

// Enum with comma-separated case declarations
@Generable(description: "The API response status")
private enum ApiResponse: Equatable {
  case pending, success(data: String)
  case error(message: String)
}

// Enum with explicit Optional<T> syntax for associated values
@Generable
private enum DataResult: Equatable {
  case data(value: String?)
  case error(code: Swift.Optional<Int>)
  case empty
}
