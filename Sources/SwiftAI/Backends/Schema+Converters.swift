#if canImport(FoundationModels)
import FoundationModels
import Foundation

@available(iOS 26.0, macOS 26.0, *)
extension Schema {
  /// Converts self to FoundationModels.GenerationSchema.
  public func toGenerationSchema() throws -> GenerationSchema {
    let dynamicSchema = self.toDynamicGenerationSchema()
    // TODO: Think if we need to catch errors here and change them to our own abstractions.
    return try GenerationSchema(root: dynamicSchema, dependencies: [])
  }

  fileprivate func toDynamicGenerationSchema() -> DynamicGenerationSchema {
    // TODO: Add comprehensive error handling for schema conversion
    switch self {
    case .object(let properties, let metadata):
      return convertObject(properties: properties, metadata: metadata)

    case .array(let items, let constraints, let metadata):
      return convertArray(items: items, constraints: constraints, metadata: metadata)

    case .string(_, _):
      // TODO: Convert string constraints to guides
      return DynamicGenerationSchema(type: String.self, guides: [])

    case .integer(_, _):
      // TODO: Convert integer constraints to guides
      return DynamicGenerationSchema(type: Int.self, guides: [])

    case .number(_, _):
      // TODO: Convert number constraints to guides
      return DynamicGenerationSchema(type: Double.self, guides: [])

    case .boolean(_, _):
      // TODO: Convert boolean constraints to guides
      return DynamicGenerationSchema(type: Bool.self, guides: [])

    case .anyOf(let schemas, let metadata):
      return convertAnyOf(schemas: schemas, metadata: metadata)
    }
  }
}

@available(iOS 26.0, macOS 26.0, *)
private func convertObject(
  properties: [String: Schema.Property],
  metadata: Schema.Metadata?
) -> DynamicGenerationSchema {
  let dynamicProperties = properties.map { name, property in
    DynamicGenerationSchema.Property(
      name: name,
      description: nil,  // FIXME: We need a description.
      schema: property.schema.toDynamicGenerationSchema(),
      isOptional: property.isOptional
    )
  }

  return DynamicGenerationSchema(
    name: metadata?.title ?? "Object",  // FIXME: We should always have a name.
    description: metadata?.description,
    properties: dynamicProperties
  )
}

@available(iOS 26.0, macOS 26.0, *)
private func convertArray(
  items: Schema,
  constraints: [AnyArrayConstraint],
  metadata: Schema.Metadata?
) -> DynamicGenerationSchema {
  // TODO: Convert array constraints (minimumElements, maximumElements)
  let itemSchema = items.toDynamicGenerationSchema()
  return DynamicGenerationSchema(
    arrayOf: itemSchema,
    minimumElements: nil,
    maximumElements: nil
  )
}

@available(iOS 26.0, macOS 26.0, *)
private func convertAnyOf(
  schemas: [Schema],
  metadata: Schema.Metadata?
) -> DynamicGenerationSchema {
  let convertedSchemas = schemas.map { $0.toDynamicGenerationSchema() }
  return DynamicGenerationSchema(
    name: metadata?.title ?? "AnyOf",  // FIXME: We should always have a name.
    description: metadata?.description,
    anyOf: convertedSchemas
  )
}
#endif
