import Foundation
import SwiftAI
import Testing

struct JSONRepairTestCase {
  let partialJSON: String
  let repairedJSON: String

  init(_ partialJSON: String, _ repairedJSON: String) {
    self.partialJSON = partialJSON
    self.repairedJSON = repairedJSON
  }
}

@Suite("JSON Repair Tests")
struct JSONRepairTests {

  static let testCases: [JSONRepairTestCase] = [
    // --- Strings ---
    JSONRepairTestCase(#"{"a": "Joh"#, #"{"a": "Joh"}"#),
    JSONRepairTestCase(#"{"a": "Jo\""#, #"{"a": "Jo\""}"#),
    JSONRepairTestCase(#"{"a": "C:\\test\""#, #"{"a": "C:\\test\""}"#),
    JSONRepairTestCase(#"{"a": "abc\\"#, #"{"a": "abc\\"}"#),  // even number of backslashes
    JSONRepairTestCase(#"{"a": "abc\\\"#, #"{"a": "abc\\"}"#),  // odd number of backslashes

    JSONRepairTestCase(#"{"a": "line1\nline2"#, #"{"a": "line1\nline2"}"#),
    JSONRepairTestCase(#"{"a": "quote: \""#, #"{"a": "quote: \""}"#),
    JSONRepairTestCase(#"{"a": "odd slash at end\\"#, #"{"a": "odd slash at end\\"}"#),

    // // --- Empty containers ---
    JSONRepairTestCase(#"{"#, "{}"),
    JSONRepairTestCase(#"["#, "[]"),

    // --- Objects with truncated key/value ---
    JSONRepairTestCase(#"{"a":"1", "b": "#, #"{"a":"1"}"#),
    JSONRepairTestCase(#"{"a": "#, "{}"),
    JSONRepairTestCase(#"{"outer": {"inner"#, "{}"),
    JSONRepairTestCase(#"{"outer": {"inner": 1, "#, #"{"outer": {"inner": 1}}"#),
    JSONRepairTestCase(#"{"outer": {"inner": 1, "inner2": "#, #"{"outer": {"inner": 1}}"#),

    // --- Arrays with truncated element ---
    JSONRepairTestCase(#"[1, 2,"#, #"[1, 2]"#),
    JSONRepairTestCase(#"[1"#, "[]"),
    JSONRepairTestCase(#"[1, {"a":"b"#, #"[1, {"a":"b"}]"#),
    JSONRepairTestCase(#"[1, {"a":"b", "#, #"[1, {"a":"b"}]"#),

    // --- Nested combinations ---
    JSONRepairTestCase(#"{"arr": [1, {"nested": "val"#, #"{"arr": [1, {"nested": "val"}]}"#),
    JSONRepairTestCase(#"[{"a": "x"}, {"b": "y"#, #"[{"a": "x"}, {"b": "y"}]"#),
    JSONRepairTestCase(#"{"k": [1, 2, 3"#, #"{"k": [1, 2]}"#),
    JSONRepairTestCase(#"{"k": [1, 2, 3,"#, #"{"k": [1, 2, 3]}"#),

    // --- Numbers ---
    JSONRepairTestCase(#"[1."#, "[]"),
    JSONRepairTestCase(#"[1.0,"#, "[1.0]"),
    JSONRepairTestCase(#"[1.0]"#, "[1.0]"),

    JSONRepairTestCase(#"[2e"#, "[]"),  // incomplete exponent
    JSONRepairTestCase(#"[2e10"#, "[]"),
    JSONRepairTestCase(#"[2e10,"#, "[2e10]"),  // complete exponent
    JSONRepairTestCase(#"[2e10]"#, "[2e10]"),  // complete exponent

    JSONRepairTestCase("[0]", "[0]"),  // bare zero
    JSONRepairTestCase("[-1, ", "[-1]"),  // negative integer
    JSONRepairTestCase("[1.23e", "[]"),  // incomplete exponent
    JSONRepairTestCase("[1.23e-4,", "[1.23e-4]"),  // full scientific notation

    // --- Booleans & null ---
    JSONRepairTestCase("[tru", "[]"),
    JSONRepairTestCase("[true", "[true]"),
    JSONRepairTestCase("[true]", "[true]"),
    JSONRepairTestCase("[1, tr", "[1]"),
    JSONRepairTestCase("[1, true", "[1, true]"),
    JSONRepairTestCase("[1, true,", "[1, true]"),

    JSONRepairTestCase("[fals", "[]"),
    JSONRepairTestCase("[false", "[false]"),
    JSONRepairTestCase("[false]", "[false]"),
    JSONRepairTestCase("[1, fals", "[1]"),
    JSONRepairTestCase("[1, false", "[1, false]"),
    JSONRepairTestCase("[1, false,", "[1, false]"),

    JSONRepairTestCase("[nul", "[]"),
    JSONRepairTestCase("[null", "[null]"),
    JSONRepairTestCase("[null]", "[null]"),
    JSONRepairTestCase("[1, nul", "[1]"),
    JSONRepairTestCase("[1, null", "[1, null]"),
    JSONRepairTestCase("[1, null,", "[1, null]"),

    JSONRepairTestCase(#"{"a": [tru"#, #"{}"#),
    JSONRepairTestCase(#"{"a": [false"#, #"{"a": [false]}"#),
    JSONRepairTestCase(#"{"a": [null"#, #"{"a": [null]}"#),

    JSONRepairTestCase("[true, null, fals", "[true, null]"),
    JSONRepairTestCase("[false, tru", "[false]"),

    // --- Deep nesting ---
    JSONRepairTestCase(#"{"a": {"b": {"c": {"d": "#, "{}"),
    JSONRepairTestCase(
      #"{"a": {"b": {"c": {"d": "xyz: "#,
      #"{"a": {"b": {"c": {"d": "xyz: "}}}}"#),
    JSONRepairTestCase(
      #"{"a": {"b": {"c": {"d": "xyz", "#,
      #"{"a": {"b": {"c": {"d": "xyz"}}}}"#),
    JSONRepairTestCase(
      #"{"a": {"b": {"c": {"d": "xyz"}, "e": {"f": [1, 2"#,
      #"{"a": {"b": {"c": {"d": "xyz"}, "e": {"f": [1]}}}}"#),
    JSONRepairTestCase(#"[[[1, 2, "#, #"[[[1, 2]]]"#),

    // --- With whitespace ---
    JSONRepairTestCase(#"  {"a": "b"  "#, #"{"a": "b"  }"#),
    JSONRepairTestCase(#"  {"a": "b  "#, #"{"a": "b  "}"#),

    // --- Empty input ---
    JSONRepairTestCase("", ""),

    // --- Misc ---
    JSONRepairTestCase("[1,2,", "[1,2]"),
    JSONRepairTestCase(#"{"a":1,"#, #"{"a":1}"#),

    JSONRepairTestCase(#"{"key": {"sub": ["a", "b""#, #"{"key": {"sub": ["a", "b"]}}"#),
    JSONRepairTestCase(#"[{"k":1}, {"k2":2}, "#, #"[{"k":1}, {"k2":2}]"#),
    JSONRepairTestCase(#"[{"k": [1,2,3]}, {"x": tru"#, #"[{"k": [1,2,3]}]"#),
  ]

  @Test("JSON Repair", arguments: testCases)
  func testJSONRepair(testCase: JSONRepairTestCase) throws {
    let result = repair(json: testCase.partialJSON)
    #expect(
      result == testCase.repairedJSON)
  }

  @Test("JSON Repair - Valid JSON should remain unchanged")
  func testValidJSONRemainUnchanged() throws {
    let validJSONs = [
      #"{"name": "John", "age": 30}"#,
      #"[1, 2, 3, {"key": "value"}]"#,
      #"{"nested": {"array": [true, false, null]}}"#,
      #"[]"#,
      #"{}"#,
      #"null"#,
      #"true"#,
      #"false"#,
      #"42"#,
      #""string""#,
    ]

    for validJSON in validJSONs {
      let result = repair(json: validJSON)
      #expect(
        result == validJSON,
        "Valid JSON should remain unchanged. Input: \(validJSON), Output: \(result)")
    }
  }

  @Test("JSON Repair - Whitespace only")
  func testWhitespaceOnly() throws {
    let result = repair(json: "   \n\t  ")
    #expect(result.isEmpty, "Whitespace-only input should return empty string")
  }

  @Test("JSON Repair - Complex escape sequences")
  func testComplexEscapeSequences() throws {
    let testCases = [
      // Unicode escapes
      (input: #"{"unicode": "\u00"#, expected: #"{"unicode": "\u00"}"#),
      // Mixed escapes
      (input: #"{"mixed": "line1\nline2\""#, expected: #"{"mixed": "line1\nline2\""}"#),
      // Tab escapes
      (input: #"{"tab": \t\t "col1\tcol2\""#, expected: #"{"tab": \t\t "col1\tcol2\""}"#),
    ]

    for testCase in testCases {
      let result = repair(json: testCase.input)
      #expect(
        result == testCase.expected)

    }
  }

  @Test("JSON Repair - Nested string with quotes")
  func testNestedStringWithQuotes() throws {
    let testCases = [
      // String containing escaped quotes
      (input: #"{"message": "He said \"Hello"#, expected: #"{"message": "He said \"Hello"}"#),
      // Multiple levels of escaping
      (input: #"{"path": "C:\\Users\\\"John\\\""#, expected: #"{"path": "C:\\Users\\\"John\\\""}"#),
    ]

    for testCase in testCases {
      let result = repair(json: testCase.input)
      #expect(result == testCase.expected)
    }
  }

  @Test("JSON Repair - Verify repaired JSON is valid")
  func testRepairedJSONIsValid() throws {
    // Test that all repaired results are actually valid JSON
    for testCase in Self.testCases {
      if testCase.partialJSON.isEmpty {
        continue
      }

      let repaired = repair(json: testCase.partialJSON)

      // Verify the repaired JSON is valid by attempting to parse it
      guard let data = repaired.data(using: .utf8) else {
        Issue.record("Repaired JSON could not be encoded as UTF-8: \(repaired)")
        continue
      }

      do {
        _ = try JSONSerialization.jsonObject(with: data, options: [])
      } catch {
        Issue.record("Repaired JSON is not valid: \(repaired) - Error: \(error)")
      }
    }
  }
}
