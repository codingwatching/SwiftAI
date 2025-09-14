import Foundation
import SwiftAI

/// An LLM implementation that crashes when any property or method is accessed.
/// Used in tests where LLM functionality should never be called (e.g., availability-gated tests).
final class CrashingLLM: LLM, @unchecked Sendable {
  var isAvailable: Bool {
    fatalError("CrashingLLM.isAvailable should not be accessed in tests")
  }

  var availability: LLMAvailability {
    fatalError("CrashingLLM.availability should not be accessed in tests")
  }

  init() {}

  func makeSession(tools: [any Tool], messages: [Message]) -> NullLLMSession {
    fatalError("CrashingLLM.makeSession should not be called in tests")
  }

  func reply<T: Generable>(
    to messages: [Message],
    returning type: T.Type,
    tools: [any Tool],
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    fatalError("CrashingLLM.reply should not be called in tests")
  }
}
