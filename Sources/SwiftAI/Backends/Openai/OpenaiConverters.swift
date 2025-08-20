import Foundation
import OpenAI

// MARK: - Message Conversion

extension CreateModelResponseQuery.Input {
  /// Creates an Input from SwiftAI messages, properly handling tool calls.
  static func from(_ messages: [Message]) throws -> CreateModelResponseQuery.Input {
    return .inputItemList(
      try messages.flatMap { try $0.asOpenaiInputItems }
    )
  }
}

// MARK: - Default Implementation

extension Message {
  fileprivate var asOpenaiInputItems: [InputItem] {
    get throws {
      switch self {
      case .user(let userMessage):
        return try userMessage.asOpenaiInputItems
      case .system(let systemMessage):
        return try systemMessage.asOpenaiInputItems
      case .ai(let aiMessage):
        return try aiMessage.asOpenaiInputItems
      case .toolOutput(let toolOutput):
        return toolOutput.asOpenaiInputItems
      }
    }
  }

  // TODO: Revisit if we can get rid of this method in favor of inlining it in sub messages.
  fileprivate var asOpenaiEasyInputMessage: EasyInputMessage {
    get throws {
      let role: EasyInputMessage.RolePayload =
        switch self {
        case .system:
          .system
        case .user:
          .user
        case .ai:
          .assistant
        case .toolOutput:
          assertionFailure("Tool output messages should not be converted to EasyInputMessage")
          throw LLMError.generalError(
            "Tool output messages should be converted using asOpenaiInputItems, not asOpenaiEasyInputMessage"
          )
        }

      let textContent = chunks.compactMap { chunk in
        switch chunk {
        case .text(let text):
          return text
        case .structured(let content):
          return content.jsonString  // TODO: We should look if we can send structured content to Openai.
        case .toolCall(_):
          return nil  // Tool calls are handled separately in InputItems
        }
      }.joined(separator: "")

      return EasyInputMessage(
        role: role,
        content: .textInput(textContent)
      )
    }
  }
}

// MARK: - Message Type Implementations

extension Message.UserMessage {
  fileprivate var asOpenaiInputItems: [InputItem] {
    get throws {
      return [.inputMessage(try Message.user(self).asOpenaiEasyInputMessage)]
    }
  }
}

extension Message.SystemMessage {
  fileprivate var asOpenaiInputItems: [InputItem] {
    get throws {
      return [.inputMessage(try Message.system(self).asOpenaiEasyInputMessage)]
    }
  }
}

extension Message.AIMessage {
  fileprivate var asOpenaiInputItems: [InputItem] {
    get throws {
      var items: [InputItem] = []

      // Add text content as EasyInputMessage if there's any non-tool-call content
      let hasNonToolContent = chunks.contains { chunk in
        switch chunk {
        case .text(_), .structured(_):
          return true
        case .toolCall(_):
          return false
        }
      }

      if hasNonToolContent {
        items.append(.inputMessage(try Message.ai(self).asOpenaiEasyInputMessage))
      }

      // Extract tool calls from the message and add each as a separate FunctionToolCall item
      let toolCalls = chunks.compactMap { chunk -> ToolCall? in
        if case .toolCall(let toolCall) = chunk {
          return toolCall
        }
        return nil
      }

      for toolCall in toolCalls {
        let functionToolCall = Components.Schemas.FunctionToolCall(
          id: nil,
          _type: .functionCall,
          callId: toolCall.id,
          name: toolCall.toolName,
          arguments: toolCall.arguments.jsonString,
          status: nil
        )
        items.append(.item(.functionToolCall(functionToolCall)))
      }

      return items
    }
  }
}

extension Message.ToolOutput {
  fileprivate var asOpenaiInputItems: [InputItem] {
    // TODO: This log is repeated several times in the codebase. Refactor it.
    let outputText = chunks.compactMap { chunk in
      switch chunk {
      case .text(let text):
        return text
      case .structured(let content):
        return content.jsonString
      case .toolCall(_):
        return nil  // Tool calls shouldn't be in tool outputs
      }
    }.joined(separator: "")

    let functionCallOutput = Components.Schemas.FunctionCallOutputItemParam(
      id: nil,  // Not required for input
      callId: id,
      _type: .functionCallOutput,
      output: outputText,
      status: nil
    )

    return [.item(Components.Schemas.Item.functionCallOutputItemParam(functionCallOutput))]
  }
}

// MARK: - Schema Conversion

/// Converts SwiftAI Schema to Openai JSONSchema format.
func convertSchemaToJSONSchema(
  _ schema: Schema,
  isOptional: Bool = false
) throws -> JSONSchema {
  switch schema {
  case .object(let name, let description, let properties):
    return try convertObjectSchema(
      name: name, description: description, properties: properties)
  case .string(let constraints):
    return convertStringSchema(
      constraints: constraints, isOptional: isOptional)
  case .integer(let constraints):
    return convertIntegerSchema(
      constraints: constraints, isOptional: isOptional)
  case .number(let constraints):
    return convertNumberSchema(
      constraints: constraints, isOptional: isOptional)
  case .boolean(let constraints):
    return convertBooleanSchema(
      constraints: constraints, isOptional: isOptional)
  case .array(let itemSchema, let constraints):
    return try convertArraySchema(
      itemSchema: itemSchema, constraints: constraints, isOptional: isOptional)
  case .anyOf(let name, let description, let schemas):
    return try convertAnyOfSchema(name: name, description: description, schemas: schemas)
  }
}

// MARK: - Schema Type Converters

private func convertObjectSchema(
  name: String,
  description: String?,
  properties: [String: Schema.Property]
) throws -> JSONSchema {
  let jsonProperties = try properties.mapValues { property in
    try convertSchemaToJSONSchema(property.schema, isOptional: property.isOptional)
  }

  var fields: [JSONSchemaField] = [
    .type(.object),
    .title(name),
    .properties(jsonProperties),
    // Openai requires that every property in the object schema must be listed as required.
    // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
    .required(Array(properties.keys)),
    // additionalProperties must be false.
    // https://platform.openai.com/docs/guides/structured-outputs#additionalproperties-false-must-always-be-set-in-objects
    .additionalProperties(JSONSchema.boolean(false)),
  ]

  if let description {
    fields.append(.description(description))
  }

  return JSONSchema(fields: fields)
}

private func convertStringSchema(
  constraints: [StringConstraint],
  isOptional: Bool
) -> JSONSchema {
  var fields: [JSONSchemaField] = []

  if isOptional {
    // Openai emulates optional fields using a union type with "null".
    // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
    fields.append(.type(.types(["string", "null"])))
  } else {
    fields.append(.type(.string))
  }

  for constraint in constraints {
    switch constraint {
    case .pattern(let regex):
      fields.append(.pattern(regex))
    case .constant(let value):
      fields.append(.enumValues([value]))
    case .anyOf(let options):
      fields.append(.enumValues(options))
    }
  }

  return JSONSchema(fields: fields)
}

private func convertIntegerSchema(
  constraints: [IntConstraint],
  isOptional: Bool
) -> JSONSchema {
  var fields: [JSONSchemaField] = []

  if isOptional {
    // Openai emulates optional fields using a union type with "null".
    // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
    fields.append(.type(.types(["integer", "null"])))
  } else {
    fields.append(.type(.integer))
  }

  // TODO: Support integer constraints.
  // For now skipping them because the underlying SDK converts them to Decimal and Openai fails at decoding them.
  _ = constraints

  return JSONSchema(fields: fields)
}

private func convertNumberSchema(
  constraints: [DoubleConstraint],
  isOptional: Bool
) -> JSONSchema {
  var fields: [JSONSchemaField] = []

  if isOptional {
    // Openai emulates optional fields using a union type with "null".
    // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
    fields.append(.type(.types(["number", "null"])))
  } else {
    fields.append(.type(.number))
  }

  // TODO: Support double constraints.
  // For now skipping them because the underlying SDK converts them to Decimal and Openai fails at decoding them.
  _ = constraints

  return JSONSchema(fields: fields)
}

private func convertBooleanSchema(
  constraints: [BoolConstraint],
  isOptional: Bool
) -> JSONSchema {
  if isOptional {
    // Openai emulates optional fields using a union type with "null".
    // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
    return JSONSchema(fields: [.type(.types(["boolean", "null"]))])
  } else {
    return JSONSchema(fields: [.type(.boolean)])
  }
}

private func convertArraySchema(
  itemSchema: Schema,
  constraints: [AnyConstraint],
  isOptional: Bool
) throws -> JSONSchema {
  var fields: [JSONSchemaField] = []

  // Handle optional types with union ["array", "null"]
  if isOptional {
    // Openai emulates optional fields using a union type with "null".
    // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
    fields.append(.type(.types(["array", "null"])))
  } else {
    fields.append(.type(.array))
  }

  for constraint in constraints {
    switch constraint.payload {
    case .this(let kind):
      switch kind {
      case .array(let arrayConstraint):
        switch arrayConstraint {
        case .count(let lowerBound, let upperBound):
          if let lowerBound = lowerBound {
            fields.append(.minItems(lowerBound))
          }
          if let upperBound = upperBound {
            fields.append(.maxItems(upperBound))
          }
        }
      default:
        // Skip non-array constraints
        break
      }
    case .sub:
      // Sub-constraints are applied to array items, not the array itself
      break
    }
  }

  let itemsSchema = try convertSchemaToJSONSchema(itemSchema)
  fields.append(.items(itemsSchema))

  return JSONSchema(fields: fields)
}

private func convertAnyOfSchema(
  name: String,
  description: String?,
  schemas: [Schema]
) throws -> JSONSchema {
  let convertedSchemas = try schemas.map { try convertSchemaToJSONSchema($0) }
  var fields: [JSONSchemaField] = [
    .anyOf(convertedSchemas)
  ]

  fields.append(.title(name))
  if let description {
    fields.append(.description(description))
  }

  return JSONSchema(fields: fields)
}

private func typeName<T: Generable>(of type: T.Type) -> String {
  String(describing: type)
}

private func extractTypeDescription(from schema: Schema) -> String? {
  switch schema {
  case .object(_, let description, _):
    return description
  case .anyOf(_, let description, _):
    return description
  case .string, .integer, .number, .boolean, .array:
    return nil  // No description for primitive types or arrays
  }
}

/// Creates structured output configuration for Openai API from SwiftAI Schema.
func makeStructuredOutputConfig<T: Generable>(for type: T.Type) throws
  -> CreateModelResponseQuery.TextResponseConfigurationOptions.OutputFormat
  .StructuredOutputsConfig
{
  // TODO: Check that T is a struct (Root must be a struct ; Openai requires an object as a root).

  let schema = type.schema
  let jsonSchema = try convertSchemaToJSONSchema(schema)

  return CreateModelResponseQuery.TextResponseConfigurationOptions.OutputFormat
    .StructuredOutputsConfig(
      name: typeName(of: type),
      schema: .jsonSchema(jsonSchema),
      // TODO: Are we sending the description twice? Once here and once in the jsonSchema?
      description: extractTypeDescription(from: schema),
      strict: true
    )
}

/// Converts SwiftAI Tools to Openai FunctionTool format for function calling.
///
/// Learn more: https://platform.openai.com/docs/guides/function-calling
func convertTools(_ tools: [any SwiftAI.Tool]) throws -> [FunctionTool] {
  return try tools.map { tool in
    let functionTool = FunctionTool(
      name: tool.name,
      description: tool.description,
      parameters: try convertSchemaToJSONSchema(type(of: tool).parameters),
      strict: true  // Always use strict mode for reliable function calls.
    )
    return functionTool
  }
}

// MARK: - Openai Response Extensions

extension ResponseObject {
  var asSwiftAIMessage: Message.AIMessage {
    get throws {
      var chunks = [ContentChunk]()

      for outputItem in output {
        switch outputItem {
        case .outputMessage(let outputMessage):
          for content in outputMessage.content {
            switch content {
            case .OutputTextContent(let textContent):
              // TODO: This will also include JSON formatted output. We may want to handle that differently.
              if let structuredContent = try? StructuredContent(json: textContent.text) {
                chunks.append(.structured(structuredContent))
              } else {
                chunks.append(.text(textContent.text))
              }
            case .RefusalContent(let refusalContent):
              throw LLMError.generalError("Request refused: \(refusalContent.refusal)")
            }
          }
        case .functionToolCall(let fnCall):
          // Convert function calls to tool call chunks
          let toolCall = ToolCall(
            id: fnCall.callId,
            toolName: fnCall.name,
            arguments: try StructuredContent(json: fnCall.arguments)
          )
          chunks.append(.toolCall(toolCall))
        default:
          // TODO: Audit other output types to make sure we handle them correctly.
          // Skip other output types for now
          break
        }
      }

      return .init(chunks: chunks)
    }
  }
}
