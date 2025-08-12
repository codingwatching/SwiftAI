#if canImport(FoundationModels)
import FoundationModels
import Foundation

// MARK: - Custom Error Types

/// Errors that can occur during transcript conversion operations.
///
/// These errors provide detailed information about what went wrong during the conversion
/// process, helping developers debug issues with message content or transcript structure.
@available(iOS 26.0, macOS 26.0, *)
public enum TranscriptConversionError: Error, LocalizedError {
  /// Indicates an unknown or unsupported transcript segment type was encountered
  case unsupportedSegmentType(String)

  /// Indicates invalid JSON content that couldn't be parsed into GeneratedContent
  case invalidJSONContent(String)

  /// Indicates an internal error in the conversion logic
  case internalError(String)

  public var errorDescription: String? {
    switch self {
    case .unsupportedSegmentType(let type):
      return "Unsupported segment type: \(type)"
    case .invalidJSONContent(let content):
      return "Invalid JSON content: \(content)"
    case .internalError(let message):
      return "Internal Error: \(message)"
    }
  }
}

// MARK: - ContentChunk → Transcript.Segment Conversion

@available(iOS 26.0, macOS 26.0, *)
extension ContentChunk {
  /// Converts a `SwiftAI.ContentChunk` to a `FoundationModels.Transcript.Segment`.
  /// Returns nil for tool call chunks because they are not representable as transcript segments.
  var transcriptSegment: Transcript.Segment? {
    get throws {
      switch self {
      case .text(let content):
        let textSegment = Transcript.TextSegment(content: content)
        return .text(textSegment)

      case .structured(let jsonString):
        // TODO: Revisit source field usage - currently using empty string as default.
        let generatedContent: GeneratedContent
        do {
          generatedContent = try GeneratedContent(json: jsonString)
        } catch {
          // TODO: Improve error reporting
          throw TranscriptConversionError.invalidJSONContent(
            "Failed to parse JSON string: \(error)")
        }

        let structuredSegment = Transcript.StructuredSegment(
          source: "",  // TODO: Revisit this default value
          content: generatedContent
        )
        return .structure(structuredSegment)

      case .toolCall:
        // No equivalent Transcript.Segment for tool calls.
        return nil
      }
    }
  }
}

// MARK: - Transcript.Segment → ContentChunk Conversion

@available(iOS 26.0, macOS 26.0, *)
extension Transcript.Segment {
  /// Converts a `FoundationModels.Transcript.Segment` to a `SwiftAI.ContentChunk`.
  var contentChunk: ContentChunk {
    switch self {
    case .text(let textSegment):
      return .text(textSegment.content)

    case .structure(let structuredSegment):
      return .structured(structuredSegment.content.jsonString)

    @unknown default:
      fatalError("Unhandled case in Transcript.Segment switch")
    }
  }
}

// MARK: - Message → Transcript.Entry Conversion

@available(iOS 26.0, macOS 26.0, *)
extension Message {
  /// Converts a `SwiftAI.Message` to one or more `Transcript.Entry` objects.
  var transcriptEntries: [Transcript.Entry] {
    get throws {
      switch self.role {
      case .system:
        let segments = try chunks.compactMap { try $0.transcriptSegment }
        let instructions = Transcript.Instructions(
          segments: segments,
          toolDefinitions: []
        )
        return [.instructions(instructions)]

      case .user:
        let segments = try chunks.compactMap { try $0.transcriptSegment }
        let prompt = Transcript.Prompt(
          segments: segments,
          options: GenerationOptions(),  // TODO: Default options used
          responseFormat: nil  // TODO: Handle response format if needed
        )
        return [.prompt(prompt)]

      case .ai:
        var entries: [Transcript.Entry] = []

        let nonToolChunks = chunks.filter { chunk in
          switch chunk {
          case .text, .structured: return true
          case .toolCall: return false
          }
        }

        let toolCallChunks = chunks.compactMap { chunk -> ToolCall? in
          switch chunk {
          case .toolCall(let toolCall): return toolCall
          default: return nil
          }
        }

        // If there are content chunks, create a Response entry.
        if !nonToolChunks.isEmpty {
          let segments = try nonToolChunks.compactMap { try $0.transcriptSegment }
          let response = Transcript.Response(
            assetIDs: [],  // TODO: Default empty asset IDs
            segments: segments
          )
          entries.append(.response(response))
        }

        // If there are tool call chunks, create a ToolCalls entry.
        if !toolCallChunks.isEmpty {
          let transcriptToolCalls = try toolCallChunks.map { toolCall in
            let generatedContent = try GeneratedContent(json: toolCall.arguments)
            return Transcript.ToolCall(
              id: toolCall.id,
              toolName: toolCall.toolName,
              arguments: generatedContent
            )
          }

          let toolCalls = Transcript.ToolCalls(transcriptToolCalls)
          entries.append(.toolCalls(toolCalls))
        }

        return entries

      case .toolOutput:
        guard let toolOutput = self as? SwiftAI.ToolOutput else {
          throw TranscriptConversionError.internalError(
            "Message has toolOutput role but is not ToolOutput type")
        }

        let segments = try chunks.compactMap { try $0.transcriptSegment }
        let transcriptToolOutput = Transcript.ToolOutput(
          id: toolOutput.id,
          toolName: toolOutput.toolName,
          segments: segments
        )
        return [.toolOutput(transcriptToolOutput)]
      }
    }
  }
}

// MARK: - Forward Conversion: [Message] → Transcript

@available(iOS 26.0, macOS 26.0, *)
extension Transcript {
  /// Creates a `FoundationModels.Transcript` from an array of `SwiftAI.Messages`
  init(messages: [any Message], tools: [any Tool] = []) throws {
    // Convert all messages to transcript entries
    var allEntries: [Transcript.Entry] = []
    for message in messages {
      let entries = try message.transcriptEntries
      allEntries.append(contentsOf: entries)
    }

    // Create tool definitions from provided tools
    let toolDefinitions = tools.map { tool in
      let foundationTool = FoundationModelsToolAdapter(wrapping: tool)
      return Transcript.ToolDefinition(tool: foundationTool)
    }

    // Add tool definitions to Instructions entry
    if !toolDefinitions.isEmpty {
      if let firstInstructionsIndex = allEntries.firstIndex(where: { entry in
        if case .instructions = entry { return true }
        return false
      }) {
        guard case .instructions(let currentInstructions) = allEntries[firstInstructionsIndex]
        else {
          // This should never happen.
          throw TranscriptConversionError.internalError(
            "Expected instructions entry at index \(firstInstructionsIndex)")
        }

        // Create new instructions with tool definitions
        let updatedInstructions = Transcript.Instructions(
          segments: currentInstructions.segments,
          toolDefinitions: toolDefinitions
        )

        // Replace the entry
        allEntries[firstInstructionsIndex] = .instructions(updatedInstructions)
      } else {
        // No Instructions entry exists, create one with tool definitions
        let newInstructions = Transcript.Instructions(
          segments: [],
          toolDefinitions: toolDefinitions
        )

        // Insert at the beginning
        allEntries.insert(.instructions(newInstructions), at: 0)
      }
    }

    self.init(entries: allEntries)
  }
}

// MARK: - Reverse Conversion: Transcript → [Message]

@available(iOS 26.0, macOS 26.0, *)
extension Transcript.Entry {
  /// Converts a `FoundationModels.Transcript.Entry` to a `SwiftAI.Message`
  var message: (any Message) {
    get throws {
      switch self {
      case .instructions(let instructions):
        let chunks = instructions.segments.map { $0.contentChunk }
        return SystemMessage(chunks: chunks)

      case .prompt(let prompt):
        let chunks = prompt.segments.map { $0.contentChunk }
        return UserMessage(chunks: chunks)

      case .response(let response):
        let chunks = response.segments.map { $0.contentChunk }
        return AIMessage(chunks: chunks)

      case .toolCalls(let toolCalls):
        let chunks = toolCalls.map { toolCall in
          let swiftAIToolCall = SwiftAI.ToolCall(
            id: toolCall.id,
            toolName: toolCall.toolName,
            arguments: toolCall.arguments.jsonString
          )
          return ContentChunk.toolCall(swiftAIToolCall)
        }
        return AIMessage(chunks: chunks)

      case .toolOutput(let toolOutput):
        let chunks = toolOutput.segments.map { $0.contentChunk }
        return SwiftAI.ToolOutput(
          id: toolOutput.id,
          toolName: toolOutput.toolName,
          chunks: chunks
        )

      @unknown default:
        throw TranscriptConversionError.unsupportedSegmentType("Unknown transcript entry type")
      }
    }
  }
}

@available(iOS 26.0, macOS 26.0, *)
extension Transcript {
  /// Converts a `FoundationModels.Transcript` back to an array of `SwiftAI.Messages`
  var messages: [any Message] {
    get throws {
      let entries = Array(self)

      // Step 1: Convert each entry to a message
      var individualMessages: [any Message] = []
      for entry in entries {
        let message = try entry.message
        individualMessages.append(message)
      }

      // Step 2: Compact adjacent messages with the same role
      return try compactAdjacentMessages(individualMessages)
    }
  }
}

/// Compacts adjacent messages with the same role by merging their chunks
@available(iOS 26.0, macOS 26.0, *)
private func compactAdjacentMessages(_ messages: [any Message]) throws -> [any Message] {
  guard messages.count > 1 else { return messages }

  var compactedMessages: [any Message] = []
  var currentMessage = messages[0]

  for i in 1..<messages.count {
    let nextMessage = messages[i]

    if canMergeMessages(currentMessage, nextMessage) {
      currentMessage = try mergeMessages(currentMessage, nextMessage)
    } else {
      compactedMessages.append(currentMessage)
      currentMessage = nextMessage
    }
  }

  compactedMessages.append(currentMessage)

  return compactedMessages
}

@available(iOS 26.0, macOS 26.0, *)
private func canMergeMessages(_ message1: any Message, _ message2: any Message) -> Bool {
  guard message1.role == message2.role else { return false }

  switch message1.role {
  case .system, .user, .ai:
    return true
  case .toolOutput:
    return false
  }
}

@available(iOS 26.0, macOS 26.0, *)
private func mergeMessages(_ message1: any Message, _ message2: any Message) throws -> any Message {
  let allChunks = message1.chunks + message2.chunks

  switch message1.role {
  case .system:
    return SystemMessage(chunks: allChunks)
  case .user:
    return UserMessage(chunks: allChunks)
  case .ai:
    return AIMessage(chunks: allChunks)
  case .toolOutput:
    throw TranscriptConversionError.internalError(
      "Cannot merge messages with toolOutput role")
  }
}

#endif
