#if canImport(FoundationModels)
import Foundation
import SwiftAI
import Testing

import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
@Test func systemLLMBasicTextGeneration() async throws {
  let systemLLM = SystemLLM()

  // Skip test if Apple Intelligence not available
  guard systemLLM.isAvailable else {
    // TODO: How to handle such cases in tests.
    return  // Test passes by skipping
  }

  let reply: LLMReply<String>
  do {
    reply = try await systemLLM.reply(
      to: [UserMessage(text: "Say hello in exactly one word.")],
    )
  } catch {
    throw error
  }

  #expect(!reply.content.isEmpty)
  #expect(reply.history.count == 2)
  #expect(reply.history[0].role == .user)
  #expect(reply.history[1].role == .ai)
}
#endif
