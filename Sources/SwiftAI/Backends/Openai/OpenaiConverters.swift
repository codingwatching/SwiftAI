import Foundation
import OpenAI
import OrderedCollections

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

      return EasyInputMessage(
        role: role,
        content: .textInput(self.text)  // TODO: We should look if we can send structured content to Openai.
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
      if !chunks.isEmpty {
        items.append(.inputMessage(try Message.ai(self).asOpenaiEasyInputMessage))
      }

      // Add tool calls from the new toolCalls property
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
    let functionCallOutput = Components.Schemas.FunctionCallOutputItemParam(
      id: nil,  // Not required for input
      callId: id,
      _type: .functionCallOutput,
      output: self.text,
      status: nil  // TODO: Add status
    )

    return [.item(Components.Schemas.Item.functionCallOutputItemParam(functionCallOutput))]
  }
}

// MARK: - Schema Conversion

func convertRootSchemaToOpenaiSupportedJsonSchema(_ schema: Schema) throws -> JSONSchema {
  guard case .object(let name, let description, let properties) = schema.unwrapped else {
    // Root object must be an object.
    // https://platform.openai.com/docs/guides/structured-outputs#root-objects-must-not-be-anyof-and-must-be-an-object
    throw LLMError.generalError("Root schema must be an object, got \(schema)")
  }
  return try convertObjectSchema(
    name: name,
    description: description,
    properties: properties
  )
}

/// Converts SwiftAI Schema to Openai JSONSchema format.
private func convertSwiftAISchemaToJSONSchema(_ schema: Schema, propertyDescription: String? = nil)
  throws
  -> JSONSchema
{

  // Sometimes both the property description and the type description are provided.
  // We combine them using a separator to avoid losing information.
  //
  // Note: Emitting {"ref": "...", "description": "..."} won't work because OpenAI does
  // not allow descriptions on properties that use $ref.
  let descriptionSeparator = " • "

  switch schema.unwrapped {
  case .object(let name, let typeDescription, let properties):
    return try convertObjectSchema(
      name: name,
      description: combineDescriptions(
        propertyDescription, typeDescription, using: descriptionSeparator),
      properties: properties)
  case .anyOf(let name, let typeDescription, let schemas):
    return try convertAnyOfSchema(
      name: name,
      description: combineDescriptions(
        propertyDescription, typeDescription, using: descriptionSeparator),
      schemas: schemas)
  case .string(let constraints):
    return convertStringSchema(
      constraints: constraints, isOptional: schema.isOptional, description: propertyDescription)
  case .integer(let constraints):
    return convertIntegerSchema(
      constraints: constraints, isOptional: schema.isOptional, description: propertyDescription)
  case .number(let constraints):
    return convertNumberSchema(
      constraints: constraints, isOptional: schema.isOptional, description: propertyDescription)
  case .boolean(let constraints):
    return convertBooleanSchema(
      constraints: constraints, isOptional: schema.isOptional, description: propertyDescription)
  case .array(let itemSchema, let constraints):
    return try convertArraySchema(
      itemSchema: itemSchema, constraints: constraints, isOptional: schema.isOptional,
      description: propertyDescription)
  case .optional(_):
    assertionFailure("Impossible case. Type was already unwrapped. This should never happen.")
    return JSONSchema(fields: [])
  }
}

// MARK: - Schema Type Converters

private func convertObjectSchema(
  name: String,
  description: String?,
  properties: OrderedDictionary<String, Schema.Property>
) throws -> JSONSchema {
  let jsonProperties = try properties.map { key, property in
    (
      key,
      try convertSwiftAISchemaToJSONSchema(
        property.schema, propertyDescription: property.description)
    )
  }

  var fields: [JSONSchemaField] = [
    // Root object must be an object.
    // https://platform.openai.com/docs/guides/structured-outputs#root-objects-must-not-be-anyof-and-must-be-an-object
    .type(.object),
    .title(name),
    // Order of properties is not guaranteed to be preserved because the Swift dictionaries are unordered.
    // https://platform.openai.com/docs/guides/structured-outputs#key-ordering
    .properties(Dictionary(uniqueKeysWithValues: jsonProperties)),
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
  isOptional: Bool,
  description: String? = nil
) -> JSONSchema {
  var fields: [JSONSchemaField] = []

  if isOptional {
    // Openai emulates optional fields using a union type with "null".
    // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
    fields.append(.type(.types(["string", "null"])))
  } else {
    fields.append(.type(.string))
  }

  if let description {
    fields.append(.description(description))
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
  isOptional: Bool,
  description: String? = nil
) -> JSONSchema {
  var fields: [JSONSchemaField] = []

  if isOptional {
    // Openai emulates optional fields using a union type with "null".
    // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
    fields.append(.type(.types(["integer", "null"])))
  } else {
    fields.append(.type(.integer))
  }

  if let description {
    fields.append(.description(description))
  }

  for constraint in constraints {
    switch constraint {
    case .range(let lowerBound, let upperBound):
      if let lower = lowerBound {
        fields.append(.minimum(lower))
      }
      if let upper = upperBound {
        fields.append(.maximum(upper))
      }
    }
  }

  return JSONSchema(fields: fields)
}

private func convertNumberSchema(
  constraints: [DoubleConstraint],
  isOptional: Bool,
  description: String? = nil
) -> JSONSchema {
  var fields: [JSONSchemaField] = []

  if isOptional {
    // Openai emulates optional fields using a union type with "null".
    // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
    fields.append(.type(.types(["number", "null"])))
  } else {
    fields.append(.type(.number))
  }

  if let description {
    fields.append(.description(description))
  }

  for constraint in constraints {
    switch constraint {
    case .range(let lowerBound, let upperBound):
      if let lower = lowerBound {
        fields.append(.minimum(lower))
      }
      if let upper = upperBound {
        fields.append(.maximum(upper))
      }
    }
  }

  return JSONSchema(fields: fields)
}

private func convertBooleanSchema(
  constraints: [BoolConstraint],
  isOptional: Bool,
  description: String? = nil
) -> JSONSchema {
  var fields: [JSONSchemaField] = []

  if isOptional {
    // Openai emulates optional fields using a union type with "null".
    // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
    fields.append(.type(.types(["boolean", "null"])))
  } else {
    fields.append(.type(.boolean))
  }

  if let description {
    fields.append(.description(description))
  }

  return JSONSchema(fields: fields)
}

private func convertArraySchema(
  itemSchema: Schema,
  constraints: [ArrayConstraint],
  isOptional: Bool,
  description: String? = nil
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

  if let description {
    fields.append(.description(description))
  }

  for constraint in constraints {
    switch constraint {
    case .count(let lowerBound, let upperBound):
      if let lowerBound = lowerBound {
        fields.append(.minItems(lowerBound))
      }
      if let upperBound = upperBound {
        fields.append(.maxItems(upperBound))
      }
    }
  }

  let itemsSchema = try convertSwiftAISchemaToJSONSchema(itemSchema)
  fields.append(.items(itemsSchema))

  return JSONSchema(fields: fields)
}

private func convertAnyOfSchema(
  name: String,
  description: String?,
  schemas: [Schema]
) throws -> JSONSchema {
  let convertedSchemas = try schemas.map { try convertSwiftAISchemaToJSONSchema($0) }
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
  case .optional(let wrapped):
    return extractTypeDescription(from: wrapped)
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
  let jsonSchema = try convertRootSchemaToOpenaiSupportedJsonSchema(schema)

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
      parameters: try convertRootSchemaToOpenaiSupportedJsonSchema(type(of: tool).parameters),
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
      var toolCalls = [Message.ToolCall]()

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
          let toolCall = Message.ToolCall(
            id: fnCall.callId,
            toolName: fnCall.name,
            arguments: try StructuredContent(json: fnCall.arguments)
          )
          toolCalls.append(toolCall)
        default:
          // TODO: Audit other output types to make sure we handle them correctly.
          // Skip other output types for now
          break
        }
      }

      return .init(chunks: chunks, toolCalls: toolCalls)
    }
  }
}

/// Combines two descriptions using a separator, only adding the separator when both parts are not empty.
private func combineDescriptions(_ first: String?, _ second: String?, using separator: String)
  -> String?
{
  let firstNonEmptyOrNil = first?.isEmpty == false ? first : nil
  let secondNonEmptyOrNil = second?.isEmpty == false ? second : nil

  switch (firstNonEmptyOrNil, secondNonEmptyOrNil) {
  case (let f?, let s?):
    return "\(f)\(separator)\(s)"
  default:
    return firstNonEmptyOrNil ?? secondNonEmptyOrNil
  }
}
