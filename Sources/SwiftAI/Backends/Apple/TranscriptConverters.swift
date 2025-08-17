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

  /// Indicates an internal error in the conversion logic
  case internalError(String)

  public var errorDescription: String? {
    switch self {
    case .unsupportedSegmentType(let type):
      return "Unsupported segment type: \(type)"
    case .internalError(let message):
      return "Internal Error: \(message)"
    }
  }
}

// MARK: - ContentChunk → Transcript.Segment Conversion

@available(iOS 26.0, macOS 26.0, *)
extension ContentChunk {
  /// ContentChunk → Transcript.Segment.
  /// Returns nil for tool call chunks because they are not representable as transcript segments.
  var asTranscriptSegment: Transcript.Segment? {
    switch self {
    case .text(let content):
      let textSegment = Transcript.TextSegment(content: content)
      return .text(textSegment)

    case .structured(let content):
      return .structure(
        Transcript.StructuredSegment(
          source: "",  // TODO: Revisit this default value
          content: content.generatedContent
        )
      )

    case .toolCall:
      // No equivalent Transcript.Segment for tool calls.
      return nil
    }
  }
}

// MARK: - Transcript.Segment → ContentChunk Conversion

@available(iOS 26.0, macOS 26.0, *)
extension Transcript.Segment {
  /// Transcript.Segment → ContentChunk.
  var contentChunk: ContentChunk? {
    switch self {
    case .text(let textSegment):
      return .text(textSegment.content)

    case .structure(let structuredSegment):
      do {
        // TODO: We can convert to StructuredContent safely by mapping the GeneratedContent.Kind to StructuredContent.Kind
        // and using a JSON string fallback.
        return .structured(try StructuredContent(json: structuredSegment.content.jsonString))
      } catch {
        // If we can't parse the JSON back to StructuredContent, this is unexpected
        // since it should have been valid when created. Return nil to indicate failure.
        assertionFailure("Failed to parse JSON string: \(error)")
        return nil
      }

    @unknown default:
      assertionFailure("Unknown case in Transcript.Segment switch")
      return nil
    }
  }
}

// MARK: - Message → Transcript.Entry Conversion

@available(iOS 26.0, macOS 26.0, *)
extension Message {
  /// Message → [Transcript.Entry]
  /// One message may be converted to multiple transcript entries because
  /// we ToolCalls are represented as a separate transcript entry in FoundationModels.
  var asTranscriptEntries: [Transcript.Entry] {
    switch self {
    case .system(let message):
      let segments = message.chunks.compactMap { $0.asTranscriptSegment }
      let instructions = Transcript.Instructions(
        segments: segments,
        toolDefinitions: []
      )
      return [.instructions(instructions)]

    case .user:
      let segments = chunks.compactMap { $0.asTranscriptSegment }
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
        let segments = nonToolChunks.compactMap { $0.asTranscriptSegment }
        let response = Transcript.Response(
          assetIDs: [],  // TODO: Default empty asset IDs
          segments: segments
        )
        entries.append(.response(response))
      }

      // If there are tool call chunks, create a ToolCalls entry.
      if !toolCallChunks.isEmpty {
        let transcriptToolCalls = toolCallChunks.map { toolCall in
          return Transcript.ToolCall(
            id: toolCall.id,
            toolName: toolCall.toolName,
            arguments: toolCall.arguments.generatedContent
          )
        }

        let toolCalls = Transcript.ToolCalls(transcriptToolCalls)
        entries.append(.toolCalls(toolCalls))
      }

      return entries

    case .toolOutput(let toolOutput):
      let segments = chunks.compactMap { $0.asTranscriptSegment }
      let transcriptToolOutput = Transcript.ToolOutput(
        id: toolOutput.id,
        toolName: toolOutput.toolName,
        segments: segments
      )
      return [.toolOutput(transcriptToolOutput)]
    }
  }
}

// MARK: - Forward Conversion: [Message] → Transcript

@available(iOS 26.0, macOS 26.0, *)
extension Transcript {
  /// Creates a `FoundationModels.Transcript` from an array of `SwiftAI.Messages`
  init(messages: [Message], tools: [any Tool] = []) throws {
    // Convert all messages to transcript entries
    var allEntries: [Transcript.Entry] = []
    for message in messages {
      let entries = try message.asTranscriptEntries
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
  /// Transcript.Entry → Message
  var message: Message {
    get throws {
      switch self {
      case .instructions(let instructions):
        let chunks = instructions.segments.compactMap { $0.contentChunk }
        return .system(.init(chunks: chunks))

      case .prompt(let prompt):
        let chunks = prompt.segments.compactMap { $0.contentChunk }
        return .user(.init(chunks: chunks))

      case .response(let response):
        let chunks = response.segments.compactMap { $0.contentChunk }
        return .ai(.init(chunks: chunks))

      case .toolCalls(let toolCalls):
        let chunks = try toolCalls.map { toolCall in
          return ContentChunk.toolCall(
            .init(
              id: toolCall.id,
              toolName: toolCall.toolName,
              // TODO: We can convert to StructuredContent safely by mapping the GeneratedContent.Kind to StructuredContent.Kind
              arguments: try StructuredContent(json: toolCall.arguments.jsonString)
            ))
        }
        return .ai(.init(chunks: chunks))

      case .toolOutput(let toolOutput):
        let chunks = toolOutput.segments.compactMap { $0.contentChunk }
        return .toolOutput(
          .init(
            id: toolOutput.id,
            toolName: toolOutput.toolName,
            chunks: chunks
          ))

      @unknown default:
        throw TranscriptConversionError.unsupportedSegmentType("Unknown transcript entry type")
      }
    }
  }
}

@available(iOS 26.0, macOS 26.0, *)
extension Transcript {
  /// Converts a `FoundationModels.Transcript` back to an array of `SwiftAI.Messages`
  var messages: [Message] {
    get throws {
      let entries = Array(self)

      // Step 1: Convert each entry to a message
      var individualMessages: [Message] = []
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
private func compactAdjacentMessages(_ messages: [Message]) throws -> [Message] {
  guard messages.count > 1 else { return messages }

  var compactedMessages: [Message] = []
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
private func canMergeMessages(_ message1: Message, _ message2: Message) -> Bool {
  guard message1.role == message2.role else { return false }

  switch message1.role {
  case .system, .user, .ai:
    return true
  case .toolOutput:
    return false
  }
}

@available(iOS 26.0, macOS 26.0, *)
private func mergeMessages(_ message1: Message, _ message2: Message) throws -> Message {
  assert(message1.role == message2.role, "Cannot merge messages with different roles")

  let allChunks = message1.chunks + message2.chunks
  switch message1 {
  case .system:
    return .system(.init(chunks: allChunks))
  case .user:
    return .user(.init(chunks: allChunks))
  case .ai:
    return .ai(.init(chunks: allChunks))
  case .toolOutput:
    throw TranscriptConversionError.internalError(
      "Cannot merge messages with toolOutput role")
  }
}

@available(iOS 26.0, macOS 26.0, *)
extension StructuredContent: ConvertibleToGeneratedContent {
  public var generatedContent: GeneratedContent {
    return GeneratedContent(kind: kind.asGeneratedContentKind)
  }
}

@available(iOS 26.0, macOS 26.0, *)
extension StructuredContent.Kind {
  var asGeneratedContentKind: GeneratedContent.Kind {
    switch self {
    case .bool(let value):
      return .bool(value)
    case .null:
      return .null
    case .number(let value):
      return .number(value)
    case .string(let value):
      return .string(value)
    case .array(let elements):
      let convertedElements = elements.map { $0.generatedContent }
      return .array(convertedElements)
    case .object(let properties):
      let convertedProperties = properties.mapValues { $0.generatedContent }
      // TODO: Revisit the order of the keys.
      let orderedKeys = Array(properties.keys)
      return .structure(properties: convertedProperties, orderedKeys: orderedKeys)
    }
  }
}

#endif
