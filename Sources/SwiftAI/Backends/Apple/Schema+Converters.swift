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

  fileprivate func toDynamicGenerationSchema(extraConstraints: [ConstraintKind] = [])
    -> DynamicGenerationSchema
  {
    // TODO: Add comprehensive error handling for schema conversion
    switch self {
    case .object(let name, let description, let properties):
      guard extraConstraints.isEmpty else {
        // TODO: Replace fatalError with proper error handling system
        fatalError(
          "Object schemas don't support extra constraints, but received: \(extraConstraints)")
      }
      return convertObject(name: name, description: description, properties: properties)

    case .array(let items, let constraints):
      let extraArrayConstraints = extraConstraints.map { AnyArrayConstraint($0) }
      return convertArray(
        items: items,
        constraints: constraints + extraArrayConstraints
      )

    case .string(let constraints):
      let extraStringConstraints = extraConstraints.map { Constraint<String>(kind: $0) }
      let guides = convertStringConstraints(constraints + extraStringConstraints)
      return DynamicGenerationSchema(type: String.self, guides: guides)

    case .integer(let constraints):
      let extraIntConstraints = extraConstraints.map { Constraint<Int>(kind: $0) }
      let guides = convertIntegerConstraints(constraints + extraIntConstraints)
      return DynamicGenerationSchema(type: Int.self, guides: guides)

    case .number(let constraints):
      let extraDoubleConstraints = extraConstraints.map { Constraint<Double>(kind: $0) }
      let guides = convertDoubleConstraints(constraints + extraDoubleConstraints)
      return DynamicGenerationSchema(type: Double.self, guides: guides)

    case .boolean(_):
      // FoundationModels doesn't support boolean constraints
      if !extraConstraints.isEmpty {
        // TODO: Replace fatalError with proper error handling system
        fatalError(
          "Boolean schemas don't support extra constraints, but received: \(extraConstraints)")
      }
      return DynamicGenerationSchema(type: Bool.self, guides: [])

    case .anyOf(let name, let description, let schemas):
      if !extraConstraints.isEmpty {
        // TODO: Replace fatalError with proper error handling system
        fatalError(
          "AnyOf schemas don't support extra constraints, but received: \(extraConstraints)")
      }
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
  // TODO: ARRAY ELEMENT CONSTRAINTS DESIGN DECISION
  // We have two options for handling `.element(constraint)` array constraints:
  //
  // Option 1: Handle during macro expansion
  // Pros: Clean separation, compile-time type safety, better error messages
  // Cons: More complex macro logic, harder debugging, recursive resolution complexity
  //
  // Option 2: Handle during conversion (CHOSEN)
  // Pros: Simpler macros, flexible runtime handling, centralized conversion logic, better scalability
  // Cons: More complex conversion logic, potential runtime vs compile-time errors
  //
  // Current implementation uses Option 2 for separation of concerns and maintainability.
  // Revisit if macro complexity becomes an issue or if compile-time validation is needed.

  var minCount: Int?
  var maxCount: Int?
  var elementConstraints = [ConstraintKind]()

  for constraint in constraints {
    switch constraint.kind {
    case .array(let arrayConstraint):
      switch arrayConstraint {
      case .count(let lowerBound, let upperBound):
        if let lowerBound {
          minCount = lowerBound
        }
        if let upperBound {
          maxCount = upperBound
        }
      case .element(let constraintKind):
        elementConstraints.append(constraintKind)
      }
    default:
      // TODO: Replace fatalError with proper error handling system
      fatalError("Non-array constraint found in array constraints: \(constraint.kind)")
    }
  }

  let itemsSchema = items.toDynamicGenerationSchema(extraConstraints: elementConstraints)
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
) -> DynamicGenerationSchema {
  let convertedSchemas = schemas.map { $0.toDynamicGenerationSchema() }
  return DynamicGenerationSchema(
    name: name,
    description: description,
    anyOf: convertedSchemas
  )
}

// MARK: - Constraint Conversion Functions

@available(iOS 26.0, macOS 26.0, *)
private func convertStringConstraints(
  _ constraints: [Constraint<String>]
) -> [GenerationGuide<String>] {
  var guides: [GenerationGuide<String>] = []

  for constraint in constraints {
    switch constraint.kind {
    case .string(let stringConstraint):
      switch stringConstraint {
      case .pattern(let regex):
        do {
          guides.append(.pattern(try Regex(regex)))
        } catch {
          // TODO: Replace with proper error handling system - for now skip invalid regex
          fatalError("Invalid regex pattern: \(regex). Error: \(error)")
        }
      case .constant(let value):
        guides.append(.constant(value))
      case .anyOf(let options):
        guides.append(.anyOf(options))
      }
    default:
      // TODO: We should throw an error or log unsupported constraints
      continue
    }
  }

  return guides
}

@available(iOS 26.0, macOS 26.0, *)
private func convertIntegerConstraints(_ constraints: [Constraint<Int>]) -> [GenerationGuide<Int>] {
  var guides: [GenerationGuide<Int>] = []

  for constraint in constraints {
    switch constraint.kind {
    case .int(let intConstraint):
      switch intConstraint {
      case .range(let lowerBound, let upperBound):
        if let lower = lowerBound {
          guides.append(.minimum(lower))
        }
        if let upper = upperBound {
          guides.append(.maximum(upper))
        }
      }
    default:
      // TODO: We should throw an error or log unsupported constraints
      continue
    }
  }

  return guides
}

@available(iOS 26.0, macOS 26.0, *)
private func convertDoubleConstraints(_ constraints: [Constraint<Double>]) -> [GenerationGuide<
  Double
>] {
  var guides: [GenerationGuide<Double>] = []

  for constraint in constraints {
    switch constraint.kind {
    case .double(let doubleConstraint):
      switch doubleConstraint {
      case .range(let lowerBound, let upperBound):
        if let lower = lowerBound {
          guides.append(.minimum(lower))
        }
        if let upper = upperBound {
          guides.append(.maximum(upper))
        }
      }
    default:
      // TODO: We should throw an error or log unsupported constraints
      continue
    }
  }

  return guides
}

#endif
