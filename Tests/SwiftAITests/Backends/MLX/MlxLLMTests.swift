import Foundation
import MLXLLM
import MLXLMCommon
import Testing

@testable import SwiftAI  // FIXME: remove @testable

struct MlxLLMTests {

  init() {
    let storageDir = URL.downloadsDirectory.appending(path: "huggingface")  // FIXME: Use a temporary directory
    MlxModelManager.configureOnce(storageDirectory: storageDir)
  }

  @Test("MLX LLM can perform basic text generation")
  func testMlxLLMBasicTextGeneration() async throws {
    let configuration = LLMRegistry.llama3_2_1B_4bit
    let llm = MlxLLM(configuration: configuration)

    // Test basic text generation
    let messages = [Message.user(.init(text: "Hello, how are you?"))]

    let reply = try await llm.reply(
      to: messages,
    )

    // Verify we got a response
    #expect(reply.content.count > 0)
    #expect(reply.history.count == 2)
  }
}
