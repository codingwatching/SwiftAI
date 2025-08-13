import Foundation
import OpenAI

// MARK: - Message Conversion

extension OpenAILLM {
  /// Converts SwiftAI messages to OpenAI input format.
  func toInputFormat(_ messages: [any Message]) -> CreateModelResponseQuery.Input {
    return .inputItemList(
      messages.map { .inputMessage(toEasyInputMessage($0)) }
    )
  }

  private func toEasyInputMessage(_ message: any Message) -> EasyInputMessage {
    let role: EasyInputMessage.RolePayload =
      switch message.role {
      case .system:
        .system
      case .user:
        .user
      case .ai:
        .assistant
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

    return EasyInputMessage(
      role: role,
      content: .textInput(textContent)
    )
  }
}

// MARK: - Schema Conversion

extension OpenAILLM {
  /// Creates structured output configuration for OpenAI API from SwiftAI Schema.
  func makeStructuredOutputConfig<T: Generable>(for type: T.Type) throws
    -> CreateModelResponseQuery.TextResponseConfigurationOptions.OutputFormat
    .StructuredOutputsConfig
  {
    // TODO: Check that T is a struct (Root must be a struct ; OpenAI requires an object as a root).

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

  /// Converts SwiftAI Schema to OpenAI JSONSchema format.
  private func convertSchemaToJSONSchema(
    _ schema: Schema,
    isOptional: Bool = false,
    extraConstraints: [ConstraintKind] = []
  ) throws -> JSONSchema {
    switch schema {
    case .object(let name, let description, let properties):
      guard extraConstraints.isEmpty else {
        fatalError(
          "Object schemas don't support extra constraints, but received: \(extraConstraints)")
      }
      return try convertObjectSchema(
        name: name, description: description, properties: properties)
    case .string(let constraints):
      return convertStringSchema(
        constraints: constraints, isOptional: isOptional, extraConstraints: extraConstraints)
    case .integer(let constraints):
      return convertIntegerSchema(
        constraints: constraints, isOptional: isOptional, extraConstraints: extraConstraints)
    case .number(let constraints):
      return convertNumberSchema(
        constraints: constraints, isOptional: isOptional, extraConstraints: extraConstraints)
    case .boolean(let constraints):
      return convertBooleanSchema(
        constraints: constraints, isOptional: isOptional, extraConstraints: extraConstraints)
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
      // OpenAI requires that every property in the object schema must be listed as required.
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
    constraints: [Constraint<String>],
    isOptional: Bool,
    extraConstraints: [ConstraintKind]
  ) -> JSONSchema {
    var fields: [JSONSchemaField] = []

    if isOptional {
      // OpenAI emulates optional fields using a union type with "null".
      // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
      fields.append(.type(.types(["string", "null"])))
    } else {
      fields.append(.type(.string))
    }

    let extraConstraints = extraConstraints.map { Constraint<String>(kind: $0) }
    let allConstraints = constraints + extraConstraints

    for constraint in allConstraints {
      switch constraint.kind {
      case .string(let stringConstraint):
        switch stringConstraint {
        case .pattern(let regex):
          fields.append(.pattern(regex))
        case .constant(let value):
          fields.append(.enumValues([value]))
        case .anyOf(let options):
          fields.append(.enumValues(options))
        }
      default:
        // Skip non-string constraints
        break
      }
    }

    return JSONSchema(fields: fields)
  }

  private func convertIntegerSchema(
    constraints: [Constraint<Int>],
    isOptional: Bool,
    extraConstraints: [ConstraintKind]
  ) -> JSONSchema {
    var fields: [JSONSchemaField] = []

    if isOptional {
      // OpenAI emulates optional fields using a union type with "null".
      // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
      fields.append(.type(.types(["integer", "null"])))
    } else {
      fields.append(.type(.integer))
    }

    let extraConstraints = extraConstraints.map { Constraint<Int>(kind: $0) }
    let allConstraints = constraints + extraConstraints
    // TODO: Support integer constraints.
    // For now skipping them because the underlying SDK converts them to Decimal and OpenAI fails at decoding them.
    _ = allConstraints

    return JSONSchema(fields: fields)
  }

  private func convertNumberSchema(
    constraints: [Constraint<Double>],
    isOptional: Bool,
    extraConstraints: [ConstraintKind]
  ) -> JSONSchema {
    var fields: [JSONSchemaField] = []

    if isOptional {
      // OpenAI emulates optional fields using a union type with "null".
      // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
      fields.append(.type(.types(["number", "null"])))
    } else {
      fields.append(.type(.number))
    }

    // Concatenate regular constraints with extra constraints from element constraints
    let extraConstraints = extraConstraints.map { Constraint<Double>(kind: $0) }
    let allConstraints = constraints + extraConstraints
    // TODO: Support double constraints.
    // For now skipping them because the underlying SDK converts them to Decimal and OpenAI fails at decoding them.
    _ = allConstraints

    return JSONSchema(fields: fields)
  }

  private func convertBooleanSchema(
    constraints: [Constraint<Bool>],
    isOptional: Bool,
    extraConstraints: [ConstraintKind]
  ) -> JSONSchema {
    if isOptional {
      // OpenAI emulates optional fields using a union type with "null".
      // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
      return JSONSchema(fields: [.type(.types(["boolean", "null"]))])
    } else {
      return JSONSchema(fields: [.type(.boolean)])
    }
  }

  private func convertArraySchema(
    itemSchema: Schema,
    constraints: [AnyArrayConstraint],
    isOptional: Bool
  ) throws -> JSONSchema {
    var fields: [JSONSchemaField] = []

    // Handle optional types with union ["array", "null"]
    if isOptional {
      // OpenAI emulates optional fields using a union type with "null".
      // https://platform.openai.com/docs/guides/structured-outputs#all-fields-must-be-required
      fields.append(.type(.types(["array", "null"])))
    } else {
      fields.append(.type(.array))
    }

    var elementConstraints = [ConstraintKind]()
    for constraint in constraints {
      switch constraint.kind {
      case .array(let arrayConstraint):
        switch arrayConstraint {
        case .count(let lowerBound, let upperBound):
          if let lowerBound = lowerBound {
            fields.append(.minItems(lowerBound))
          }
          if let upperBound = upperBound {
            fields.append(.maxItems(upperBound))
          }
        case .element(let constraintKind):
          elementConstraints.append(constraintKind)
        }
      default:
        // Skip non-array constraints
        break
      }
    }

    let itemsSchema = try convertSchemaToJSONSchema(
      itemSchema, extraConstraints: elementConstraints)
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
}
