import Foundation
import OpenAI

// MARK: - Message Conversion

extension OpenAILLM {
  /// Converts SwiftAI messages to OpenAI input format.
  func toInputFormat(_ messages: [any Message]) -> CreateModelResponseQuery.Input {
    let inputItems: [InputItem] = messages.compactMap { message in
      guard let easyInputMessage = toEasyInputMessage(message) else {
        return nil
      }
      return .inputMessage(easyInputMessage)
    }

    return .inputItemList(inputItems)
  }

  /// Converts a SwiftAI Message to OpenAI EasyInputMessage.
  private func toEasyInputMessage(_ message: any Message) -> EasyInputMessage? {
    let role: EasyInputMessage.RolePayload
    switch message.role {
    case .system:
      role = .system
    case .user:
      role = .user
    case .ai:
      role = .assistant
    case .toolOutput:
      fatalError("Tool output messages are not supported in Phase 1")
    }

    // TODO: Convert to ContentPayload.inputItemContentList instead of casting everything to text.
    let textContent = message.chunks.compactMap { chunk in
      switch chunk {
      case .text(let text):
        return text
      case .structured(_):
        fatalError("Structured content is not supported in Phase 1")
      case .toolCall(_):
        fatalError("Tool calls are not supported in Phase 1")
      }
    }.joined(separator: "\n")

    guard !textContent.isEmpty else {
      return nil
    }

    return EasyInputMessage(
      role: role,
      content: .textInput(textContent)
    )
  }
}
