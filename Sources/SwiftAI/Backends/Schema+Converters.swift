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
    case .object(let name, let description, let properties):
      return convertObject(name: name, description: description, properties: properties)

    case .array(let items, let constraints):
      return convertArray(items: items, constraints: constraints)

    case .string(_):
      // TODO: Convert string constraints to guides
      return DynamicGenerationSchema(type: String.self, guides: [])

    case .integer(_):
      // TODO: Convert integer constraints to guides
      return DynamicGenerationSchema(type: Int.self, guides: [])

    case .number(_):
      // TODO: Convert number constraints to guides
      return DynamicGenerationSchema(type: Double.self, guides: [])

    case .boolean(_):
      // TODO: Convert boolean constraints to guides
      return DynamicGenerationSchema(type: Bool.self, guides: [])

    case .anyOf(let name, let description, let schemas):
      return convertAnyOf(name: name, description: description, schemas: schemas)
    }
  }
}

@available(iOS 26.0, macOS 26.0, *)
private func convertObject(
  name: String,
  description: String?,
  properties: [String: Schema.Property]
) -> DynamicGenerationSchema {
  return DynamicGenerationSchema(
    name: name,
    description: description,
    properties: properties.map { name, property in
      DynamicGenerationSchema.Property(
        name: name,
        description: property.description,
        schema: property.schema.toDynamicGenerationSchema(),
        isOptional: property.isOptional
      )
    }
  )
}

@available(iOS 26.0, macOS 26.0, *)
private func convertArray(
  items: Schema,
  constraints: [AnyArrayConstraint]
) -> DynamicGenerationSchema {
  // TODO: Convert array constraints (minimumElements, maximumElements)
  return DynamicGenerationSchema(
    arrayOf: items.toDynamicGenerationSchema(),
    minimumElements: nil,
    maximumElements: nil
  )
}

@available(iOS 26.0, macOS 26.0, *)
private func convertAnyOf(
  name: String,
  description: String?,
  schemas: [Schema]
) -> DynamicGenerationSchema {
  let convertedSchemas = schemas.map { $0.toDynamicGenerationSchema() }
  return DynamicGenerationSchema(
    name: name,
    description: description,
    anyOf: convertedSchemas
  )
}
#endif
