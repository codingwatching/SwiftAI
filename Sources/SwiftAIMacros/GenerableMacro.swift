import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// TODO: Improve formatting of generated code - currently generates compact single-line output.
// Consider using SwiftBasicFormat or manual trivia application for better readability.

struct GuideInfo {
  let description: String
  // TODO: Suppport constraints.
}

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

    let schemaDecl = try VariableDeclSyntax("public static var schema: Schema") {
      FunctionCallExprSyntax(callee: ExprSyntax(".object")) {
        LabeledExprSyntax(
          label: "properties",
          expression: DictionaryExprSyntax {
            for propertyExpr in propertyExprs {
              propertyExpr
            }
          }
        )
        LabeledExprSyntax(label: "metadata", expression: ExprSyntax("nil"))
      }
    }

    let extensionDecl = ExtensionDeclSyntax(
      extendedType: type,
      inheritanceClause: InheritanceClauseSyntax {
        InheritedTypeSyntax(type: TypeSyntax("Generable"))
      }
    ) {
      schemaDecl
    }

    return [extensionDecl]
  }

  private static func makePropertyExpressions(from structDecl: StructDeclSyntax) throws
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

  private static func makeSchemaExpression(for type: TypeSyntax, guideInfo: GuideInfo? = nil)
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

      return ExprSyntax(
        FunctionCallExprSyntax(callee: ExprSyntax(".array")) {
          LabeledExprSyntax(label: "items", expression: elementSchema)
          LabeledExprSyntax(label: "constraints", expression: ExprSyntax("[]"))
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
    let metadataExpr = makeMetadataExpression(from: guideInfo)

    if let schemaKind = typeToSchemaKind[typeName] {
      return ExprSyntax(
        FunctionCallExprSyntax(callee: ExprSyntax(stringLiteral: schemaKind)) {
          LabeledExprSyntax(label: "constraints", expression: ExprSyntax("[]"))
          LabeledExprSyntax(label: "metadata", expression: metadataExpr)
        }
      )
    } else {
      // For custom types, assume they conform to Generable and reference their schema
      // TODO: The current Schema API does not support adding descriptions and constraints to nested types.
      return ExprSyntax("\(raw: typeName).schema")
    }
  }

  private static func parseGuideAttributes(for property: VariableDeclSyntax) -> GuideInfo? {
    // Look for @Guide attributes on this property
    for attribute in property.attributes {
      if case .attribute(let attr) = attribute,
        let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self),
        identifierType.name.text == "Guide"
      {

        // Parse the description from the first argument
        if let arguments = attr.arguments?.as(LabeledExprListSyntax.self),
          let firstArg = arguments.first,
          let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
          let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
        {

          let description = String(segment.content.text)
          return GuideInfo(description: description)
        }
      }
    }
    return nil
  }

  private static func makeMetadataExpression(from guideInfo: GuideInfo?) -> ExprSyntax {
    guard let guideInfo = guideInfo else {
      return ExprSyntax("nil")
    }

    return ExprSyntax(
      FunctionCallExprSyntax(callee: ExprSyntax("Schema.Metadata")) {
        LabeledExprSyntax(
          label: "description", expression: ExprSyntax(literal: guideInfo.description))
      }
    )
  }
}

enum GenerableMacroError: Error, CustomStringConvertible {
  /// The @Generable macro was applied to a non-struct declaration (class, enum, etc.)
  case notAStruct

  /// A property uses a complex pattern that cannot be analyzed (e.g., tuple destructuring)
  case unsupportedPropertyPattern

  /// A property lacks an explicit type annotation and relies on type inference
  case missingTypeAnnotation(propertyName: String)

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
    }
  }
}
