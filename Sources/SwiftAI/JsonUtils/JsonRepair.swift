import Foundation

/// Recovers the longest valid prefix of a partial JSON string and completes it.
///
/// Non string partials are not recovered. For example `[1, 2` is recovered as `[1]`
/// and not `[1, 2]` because we don't know the final value of the second element.
///
/// Note: The input string is assumed to be a valid prefix of a JSON string.
///
/// - Parameter input: The partial JSON string to repair
/// - Returns: The repaired JSON string
///
/// ## Usage Example
///
/// ```swift
/// let input = #"{"name": "Jo"#
/// let repaired = repair(json: input)
/// print(repaired) // #"{"name": "Jo"}"#
/// ```
public func repair(json: String) -> String {
  if json.isEmpty {
    return ""
  }

  var chars = Array(json)

  // Tracking state while scanning
  var inString = false
  var escapeNext = false

  var containersStack = [Container]()

  // Scan the input string.
  for (i, c) in chars.enumerated() {
    if inString {
      if escapeNext {
        // The current char is escaped; consume and continue
        escapeNext = false
      } else if c == JSONChar.backslash {
        escapeNext = true
      } else if c == JSONChar.quote {
        // closing quote
        inString = false
      }
      // Inside a string: all structural characters are ignored.
    } else {
      // Not inside a string, handle structural characters.
      switch c {
      case JSONChar.quote:
        inString = true
      case JSONChar.openBrace:
        let container = Container(type: .object, openingIndex: i)
        containersStack.append(container)
      case JSONChar.openBracket:
        let container = Container(type: .array, openingIndex: i)
        containersStack.append(container)
      case JSONChar.closeBrace, JSONChar.closeBracket:
        if !containersStack.isEmpty {
          containersStack.removeLast()
        }
      case JSONChar.comma:
        if var top = containersStack.popLast() {
          top.lastCommaIndex = i
          containersStack.append(top)
        }
      case JSONChar.colon:
        if var top = containersStack.popLast() {
          top.lastColonIndex = i
          containersStack.append(top)
        }
      default:
        break
      }
    }
  }

  // Attempt a repair if we ended inside a "value" string.
  if inString {
    let backslashCount = countTrailingBackslashes(in: chars)
    if backslashCount % 2 == 1 {
      // Odd -> remove one backslash, then append closing quote.
      chars.removeLast()
    }
    // Append closing quote.
    chars.append(JSONChar.quote)
  }

  guard let top = containersStack.last else {
    return String(chars).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  let firstContainer = containersStack.first!

  if !isCompleteValue(in: top, chars: chars) {
    // We have an incomplete value. We backtrack to the last valid prefix.
    while let top = containersStack.last {
      // Case 1: There is a comma -> trim to just before that.
      // The prefix should already be valid.
      if let idx = top.lastCommaIndex {
        chars = Array(chars.prefix(upTo: idx))
        break  // STOP removing suffixes. We found a valid prefix.
      }
      // Case 2: No comma -> remove entire container, and move on to the next one.
      else {
        chars = Array(chars.prefix(upTo: top.openingIndex))
        containersStack.removeLast()
      }
    }
  }

  // Close any remaining open containers in the correct order (LIFO)
  while let top = containersStack.popLast() {
    chars.append(top.type == .object ? JSONChar.closeBrace : JSONChar.closeBracket)
  }

  let result = String(chars).trimmingCharacters(in: .whitespacesAndNewlines)
  if result.isEmpty {
    if firstContainer.type == .object {
      return "{}"
    } else {
      return "[]"
    }
  }
  return result
}

private enum ContainerType { case object, array }

private struct Container {
  var type: ContainerType

  /// Index of the opening '{' or '[' in the input string
  var openingIndex: Int

  /// Last comma seen in this container.
  var lastCommaIndex: Int?

  /// Last colon seen in this container.
  var lastColonIndex: Int?

  func isExpectingValue() -> Bool {
    if type == .array {
      // Arrays only have values never keys.
      return true
    }

    guard let lastColonIndex else {
      // No COLON seen so far, so the expected next atom is a KEY.
      return false
    }

    // Last border is the last COMMA or OPEN_BRACE.
    let lastBorderIndex = lastCommaIndex ?? openingIndex

    // If POS(LastBorder) < POS(LastColon) then we have either:
    // 1. OPEN_BRACE <KEY> COLON
    // 2. COMMA <KEY> COLON
    // so we must be scanning a VALUE next.
    return lastBorderIndex < lastColonIndex
  }
}

private func isCompleteValue(in container: Container, chars: [Character]) -> Bool {
  guard container.isExpectingValue() else { return false }

  // Trim trailing whitespace
  let trimmed = chars.reversed().drop(while: { $0.isWhitespace }).reversed()
  guard let last = trimmed.last else { return false }

  // Case 1: String value
  if last == JSONChar.quote {
    return true
  }

  // Case 2: Literal values
  return endsWithLiteral(trimmed, literal: "true")
    || endsWithLiteral(trimmed, literal: "false")
    || endsWithLiteral(trimmed, literal: "null")
}

/// Checks if `chars` ends with the given literal.
private func endsWithLiteral<C: Collection>(_ chars: C, literal: String) -> Bool
where C.Element == Character {
  guard chars.count >= literal.count else { return false }
  return String(chars.suffix(literal.count)) == literal
}

private enum JSONChar {
  static let openBrace: Character = "{"
  static let closeBrace: Character = "}"
  static let openBracket: Character = "["
  static let closeBracket: Character = "]"
  static let quote: Character = "\""
  static let comma: Character = ","
  static let colon: Character = ":"
  static let backslash: Character = "\\"
}

private func countTrailingBackslashes(in chars: [Character]) -> Int {
  var count = 0
  var index = chars.count - 1
  while index >= 0 && chars[index] == JSONChar.backslash {
    count += 1
    index -= 1
  }
  return count
}
