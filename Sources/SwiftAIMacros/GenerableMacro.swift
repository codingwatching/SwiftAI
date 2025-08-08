import SwiftFormat
import SwiftOperators
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// TODO: If @Guide is attached to a non generable field then it should throw an error.

public struct GenerableMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // TODO: Support enums as well.
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      throw GenerableMacroError.notAStruct
    }

    let propertyExprs = try makePropertyExpressions(from: structDecl)

    let extensionDecl = try ExtensionDeclSyntax("extension \(type.trimmed): Generable") {
      try VariableDeclSyntax("public static var schema: Schema") {
        """
        .object(
          properties: \(DictionaryExprSyntax {
              for propertyExpr in propertyExprs {
                propertyExpr
              }
            }),
          metadata: nil
        )
        """
      }
    }

    return [extensionDecl.formatted()]
  }
}

struct GuideParams {
  // The user provided description in the @Guide macro.
  let description: String?

  // The syntax nodes for the constraints attached to a property.
  // For example, `.minLength(3)`
  let constraints: [ExprSyntax]
}

private func makePropertyExpressions(from structDecl: StructDeclSyntax) throws
  -> [DictionaryElementSyntax]
{
  let storedProperties = structDecl.memberBlock.members.compactMap { member in
    member.decl.as(VariableDeclSyntax.self)
  }.filter { variableDecl in
    // Only consider stored properties (let/var without getters and without default values)
    variableDecl.bindings.allSatisfy { binding in
      binding.accessorBlock == nil && binding.initializer == nil
    }
    // TODO: Revisit whether properties with default values should be excluded from schema
  }

  // TODO: Handle @Generable with a `description` parameter.

  var propertyExpressions: [DictionaryElementSyntax] = []

  for property in storedProperties {
    for binding in property.bindings {
      guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        throw GenerableMacroError.unsupportedPropertyPattern
      }

      guard let type = binding.typeAnnotation?.type else {
        let propertyName = pattern.identifier.text
        throw GenerableMacroError.missingTypeAnnotation(propertyName: propertyName)
      }

      let propertyName = pattern.identifier.text
      let isOptional = type.is(OptionalTypeSyntax.self)

      try validateNotArrayOfOptional(type: type, propertyName: propertyName)

      // Parse @Guide attributes for this property
      let guideInfo = parseGuideAttributes(for: property)
      let schemaExpr = makeSchemaExpression(for: type, guideInfo: guideInfo)

      let propertyExpr = DictionaryElementSyntax(
        key: ExprSyntax(literal: propertyName),
        value: FunctionCallExprSyntax(callee: ExprSyntax("Schema.Property")) {
          LabeledExprSyntax(label: "schema", expression: schemaExpr)
          LabeledExprSyntax(label: "isOptional", expression: ExprSyntax(literal: isOptional))
        }
      )

      propertyExpressions.append(propertyExpr)
    }
  }

  return propertyExpressions
}

private func makeSchemaExpression(for type: TypeSyntax, guideInfo: GuideParams? = nil)
  -> ExprSyntax
{
  let typeName = type.trimmed.description

  // Handle optional types
  if let optionalType = type.as(OptionalTypeSyntax.self) {
    return makeSchemaExpression(for: optionalType.wrappedType, guideInfo: guideInfo)
  }

  // Handle array types
  if let arrayType = type.as(ArrayTypeSyntax.self) {
    let elementSchema = makeSchemaExpression(for: arrayType.element)
    let metadataExpr = makeMetadataExpression(from: guideInfo)
    let constraintsExpr = makeConstraintsExpression(
      from: guideInfo, isArray: true, elementType: arrayType.element)

    return ExprSyntax(
      FunctionCallExprSyntax(callee: ExprSyntax(".array")) {
        LabeledExprSyntax(label: "items", expression: elementSchema)
        LabeledExprSyntax(label: "constraints", expression: constraintsExpr)
        LabeledExprSyntax(label: "metadata", expression: metadataExpr)
      }
    )
  }

  // Type mapping for basic schema kinds
  let typeToSchemaKind: [String: String] = [
    "String": ".string",
    "Int": ".integer",
    "Double": ".number",
    "Bool": ".boolean",
  ]

  // Handle basic types with constraints and metadata
  if let schemaKind = typeToSchemaKind[typeName] {
    let metadataExpr = makeMetadataExpression(from: guideInfo)
    let constraintsExpr = makeConstraintsExpression(from: guideInfo)
    return ExprSyntax(
      FunctionCallExprSyntax(callee: ExprSyntax(stringLiteral: schemaKind)) {
        LabeledExprSyntax(label: "constraints", expression: constraintsExpr)
        LabeledExprSyntax(label: "metadata", expression: metadataExpr)
      }
    )
  } else {
    // For custom types, assume they conform to Generable and reference their schema
    // TODO: The current Schema API does not support adding descriptions and constraints to nested types.
    return ExprSyntax("\(raw: typeName).schema")
  }
}

private func parseGuideAttributes(for property: VariableDeclSyntax) -> GuideParams? {
  // Look for @Guide attributes on this property
  for attribute in property.attributes {
    if case .attribute(let attr) = attribute,
      let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self),
      identifierType.name.text == "Guide"
    {
      // TODO: This handles only one @Guide per property. If multiple @Guide attributes are allowed, this needs to be adjusted.
      guard let arguments = attr.arguments?.as(LabeledExprListSyntax.self),
        !arguments.isEmpty
      else {
        return nil
      }

      var description: String? = nil
      var constraints: [ExprSyntax] = []

      // Parse labeled arguments
      for arg in arguments {
        if let label = arg.label?.text {
          if label == "description" {
            if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
            {
              let desc = String(segment.content.text)
              description = desc.isEmpty ? nil : desc
            }
          }
        } else {
          // Unlabeled arguments are constraints
          constraints.append(arg.expression)
        }
      }

      // Only return GuideInfo if we have constraints or a description
      if !constraints.isEmpty || description != nil {
        return GuideParams(description: description, constraints: constraints)
      }
    }
  }
  return nil
}

private func makeConstraintsExpression(
  from guideInfo: GuideParams?,
  isArray: Bool = false,
  elementType: TypeSyntax? = nil
) -> ExprSyntax {
  guard let guideInfo = guideInfo, !guideInfo.constraints.isEmpty else {
    return ExprSyntax("[]")
  }

  let elements = guideInfo.constraints.enumerated().map { (index, constraint) in
    let expression: ExprSyntax = {
      if isArray, let elementType = elementType {
        let typeName = elementType.trimmed.description
        return ExprSyntax("AnyArrayConstraint(Constraint<[\(raw: typeName)]>\(constraint))")
      } else {
        return constraint
      }
    }()
    return ArrayElementSyntax(
      expression: expression,
      trailingComma: index < guideInfo.constraints.count - 1 ? .commaToken() : nil
    )
  }

  return ExprSyntax(ArrayExprSyntax(elements: ArrayElementListSyntax(elements)))
}

private func validateNotArrayOfOptional(type: TypeSyntax, propertyName: String) throws {
  // Handle optional types by checking their wrapped type
  if let optionalType = type.as(OptionalTypeSyntax.self) {
    try validateNotArrayOfOptional(type: optionalType.wrappedType, propertyName: propertyName)
    return
  }

  // Check if this is an array type with optional elements
  if let arrayType = type.as(ArrayTypeSyntax.self) {
    if arrayType.element.is(OptionalTypeSyntax.self) {
      let elementTypeName =
        arrayType.element.as(OptionalTypeSyntax.self)?.wrappedType.trimmed.description ?? "Unknown"
      throw GenerableMacroError.arrayOfOptionalType(
        propertyName: propertyName, elementType: elementTypeName)
    }
  }
}

private func makeMetadataExpression(from guideInfo: GuideParams?) -> ExprSyntax {
  guard let guideInfo = guideInfo,
    let description = guideInfo.description,
    !description.isEmpty
  else {
    return ExprSyntax("nil")
  }

  return ExprSyntax(
    FunctionCallExprSyntax(callee: ExprSyntax("Schema.Metadata")) {
      LabeledExprSyntax(
        label: "description", expression: ExprSyntax(literal: description))
    }
  )
}

enum GenerableMacroError: Error, CustomStringConvertible {
  /// The @Generable macro was applied to a non-struct declaration (class, enum, etc.)
  case notAStruct

  /// A property uses a complex pattern that cannot be analyzed (e.g., tuple destructuring)
  case unsupportedPropertyPattern

  /// A property lacks an explicit type annotation and relies on type inference
  case missingTypeAnnotation(propertyName: String)

  /// Arrays of optional types are not supported
  case arrayOfOptionalType(propertyName: String, elementType: String)

  var description: String {
    switch self {
    case .notAStruct:
      return "@Generable can only be applied to structs"
    case .unsupportedPropertyPattern:
      return
        "@Generable does not support complex property patterns (like tuple destructuring). Use simple property declarations like 'let name: String'."
    case .missingTypeAnnotation(let propertyName):
      return
        "Property '\(propertyName)' must have an explicit type annotation. Use 'let \(propertyName): Type' instead of relying on type inference."
    case .arrayOfOptionalType(let propertyName, let elementType):
      return
        "Property '\(propertyName)' cannot be an array of optional types '[\(elementType)?]'. Arrays of optionals are not supported. Consider using a different data structure or making the entire array optional instead."
    }
  }
}

extension DeclSyntaxParseable {
  fileprivate func formatted() -> Self {
    formatSyntaxNode(self)
  }
}

private func formatSyntaxNode<T: DeclSyntaxParseable>(_ node: T) -> T {
  var configuration = Configuration()
  configuration.indentation = .spaces(2)
  configuration.maximumBlankLines = 1
  configuration.lineBreakBeforeControlFlowKeywords = true
  configuration.lineLength = 80
  configuration.lineBreakBeforeEachArgument = true
  configuration.respectsExistingLineBreaks = false

  let formatter = SwiftFormatter(configuration: configuration)

  do {
    var output = ""
    try formatter.format(
      source: node.description,
      assumingFileURL: nil,
      to: &output
    )
    return try T(SyntaxNodeString(stringLiteral: output))
  } catch {
    return node
  }
}
