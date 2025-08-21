#if canImport(FoundationModels)
import FoundationModels
import Foundation

@available(iOS 26.0, macOS 26.0, *)
extension Schema {
  /// Converts self to FoundationModels.GenerationSchema.
  public func toGenerationSchema() throws -> GenerationSchema {
    let dynamicSchema = try self.toDynamicGenerationSchema()
    // TODO: Think if we need to catch errors here and change them to our own abstractions.
    return try GenerationSchema(root: dynamicSchema, dependencies: [])
  }

  fileprivate func toDynamicGenerationSchema()
    throws -> DynamicGenerationSchema  // TODO: Does this need to throw?
  {
    // TODO: Add comprehensive error handling for schema conversion
    switch self {
    case .object(let name, let description, let properties):
      return try convertObject(name: name, description: description, properties: properties)

    case .array(let items, let constraints):
      return try convertArray(
        items: items,
        constraints: constraints
      )

    case .string(let constraints):
      let guides = try convertStringConstraints(constraints)
      return DynamicGenerationSchema(type: String.self, guides: guides)

    case .integer(let constraints):
      let guides = convertIntegerConstraints(constraints)
      return DynamicGenerationSchema(type: Int.self, guides: guides)

    case .number(let constraints):
      let guides = convertDoubleConstraints(constraints)
      return DynamicGenerationSchema(type: Double.self, guides: guides)

    case .boolean:
      return DynamicGenerationSchema(type: Bool.self, guides: [])

    case .anyOf(let name, let description, let schemas):
      return try convertAnyOf(name: name, description: description, schemas: schemas)
    }
  }
}

@available(iOS 26.0, macOS 26.0, *)
private func convertObject(
  name: String,
  description: String?,
  properties: [String: Schema.Property]
) throws -> DynamicGenerationSchema {
  return DynamicGenerationSchema(
    name: name,
    description: description,
    properties: try properties.map { name, property throws in
      DynamicGenerationSchema.Property(
        name: name,
        description: property.description,
        schema: try property.schema.toDynamicGenerationSchema(),
        isOptional: property.isOptional
      )
    }
  )
}

@available(iOS 26.0, macOS 26.0, *)
private func convertArray(
  items: Schema,
  constraints: [ArrayConstraint]
) throws -> DynamicGenerationSchema {
  var minCount: Int?
  var maxCount: Int?

  for constraint in constraints {
    switch constraint {
    case .count(let lowerBound, let upperBound):
      if let lowerBound {
        minCount = lowerBound
      }
      if let upperBound {
        maxCount = upperBound
      }
    }
  }

  let itemsSchema = try items.toDynamicGenerationSchema()
  return DynamicGenerationSchema(
    arrayOf: itemsSchema,
    minimumElements: minCount,
    maximumElements: maxCount
  )
}

@available(iOS 26.0, macOS 26.0, *)
private func convertAnyOf(
  name: String,
  description: String?,
  schemas: [Schema]
) throws -> DynamicGenerationSchema {
  let convertedSchemas = try schemas.map { try $0.toDynamicGenerationSchema() }
  return DynamicGenerationSchema(
    name: name,
    description: description,
    anyOf: convertedSchemas
  )
}

// MARK: - Constraint Conversion Functions

@available(iOS 26.0, macOS 26.0, *)
private func convertStringConstraints(
  _ constraints: [StringConstraint]
) throws -> [GenerationGuide<String>] {
  var guides: [GenerationGuide<String>] = []

  for constraint in constraints {
    switch constraint {
    case .pattern(let regex):
      guides.append(.pattern(try Regex(regex)))
    case .constant(let value):
      guides.append(.constant(value))
    case .anyOf(let options):
      guides.append(.anyOf(options))
    }
  }

  return guides
}

@available(iOS 26.0, macOS 26.0, *)
private func convertIntegerConstraints(_ constraints: [IntConstraint]) -> [GenerationGuide<Int>] {
  var guides: [GenerationGuide<Int>] = []

  for constraint in constraints {
    switch constraint {
    case .range(let lowerBound, let upperBound):
      if let lower = lowerBound {
        guides.append(.minimum(lower))
      }
      if let upper = upperBound {
        guides.append(.maximum(upper))
      }
    }
  }

  return guides
}

@available(iOS 26.0, macOS 26.0, *)
private func convertDoubleConstraints(_ constraints: [DoubleConstraint]) -> [GenerationGuide<
  Double
>] {
  var guides: [GenerationGuide<Double>] = []

  for constraint in constraints {
    switch constraint {
    case .range(let lowerBound, let upperBound):
      if let lower = lowerBound {
        guides.append(.minimum(lower))
      }
      if let upper = upperBound {
        guides.append(.maximum(upper))
      }
    }
  }

  return guides
}

#endif
