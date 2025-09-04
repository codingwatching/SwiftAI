import Foundation
import MLXLLM
import MLXLMCommon
import Testing

@testable import SwiftAI  // FIXME: remove @testable

@Suite
struct MlxLLMTests {
  var llm: MlxLLM {
    let modelDir = ProcessInfo.processInfo.environment["MLX_TEST_MODEL_DIR"]
    let modelDirURL = URL(filePath: modelDir ?? "")

    return MlxLLM(
      configuration: ModelConfiguration(directory: modelDirURL)
    )
  }

  @Test(.enabled(if: testModelDirectoryIsSet()))
  func testMlxLLMBasicTextGeneration() async throws {
    await waitUntilAvailable(llm, timeout: .seconds(10))

    let reply = try await llm.reply(to: "Hello, how are you")

    #expect(reply.content.count > 0)
    #expect(reply.history.count == 2)
  }

  @Test
  func testIsAvailable_ModelNotAvailable_ReturnsFalse() async throws {
    let llm = MlxLLM(configuration: ModelConfiguration(id: "non-existent/model"))
    #expect(llm.isAvailable == false)
  }

  @Test
  func testReplyTo_ModelNotAvailable_ThrowsError() async throws {
    let llm = MlxLLM(configuration: ModelConfiguration(id: "non-existent/model"))

    do {
      let _ = try await llm.reply(to: "Hello, how are you?")
      Issue.record("Expected model to be unavailable, but it was available.")
    } catch {
      #expect(error is LLMError)
    }
  }
}

private func testModelDirectoryIsSet() -> Bool {
  guard let modelDir = ProcessInfo.processInfo.environment["MLX_TEST_MODEL_DIR"] else {
    return false
  }
  return !modelDir.isEmpty
}

@discardableResult
private func waitUntilAvailable(_ llm: any LLM, timeout: Duration) async -> Bool {
  let clock = ContinuousClock()
  let deadline = clock.now.advanced(by: timeout)

  if llm.isAvailable { return true }

  while clock.now < deadline {
    try? await Task.sleep(for: .milliseconds(25))
    if llm.isAvailable { return true }
  }

  return llm.isAvailable
}
