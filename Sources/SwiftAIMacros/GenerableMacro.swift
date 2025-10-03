import SwiftDiagnostics
import SwiftFormat
import SwiftOperators
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Naming Conventions

// 1. SwiftSyntax variables end with Decl/Expr/Syntax (memberDecls, bindingSyntax, typeSyntax)
// 2. Parsed syntax nodes end with Descriptor (PropertyDescriptor, GuideDescriptor)
// 3. Functions that emit code start with emit.

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
      throw GenerableMacroError(
        message: "@Generable can only be applied to structs",
        id: "notAStruct"
      )
    }

    let typeName = type.trimmed.description
    let propertyDescriptors = try parseStoredProperties(from: structDecl)
    // TODO: Extract description from @Generable macro if provided

    let extensionDecl = try ExtensionDeclSyntax(
      "nonisolated extension \(type.trimmed): SwiftAI.Generable"
    ) {
      try emitPartialStruct(typeName: typeName, properties: propertyDescriptors)
        .with(\.trailingTrivia, .newlines(2))

      try emitSchemaVariable(typeName: typeName, properties: propertyDescriptors)
        .with(\.trailingTrivia, .newlines(2))

      try emitGenerableContentVariable(typeName: typeName, properties: propertyDescriptors)
        .with(\.trailingTrivia, .newlines(2))

      try emitStructuredContentInitializer(properties: propertyDescriptors)
    }

    return [extensionDecl.formatted()]
  }
}

struct GuideDescriptor {
  // The user provided description in the @Guide macro.
  let description: String?

  // The syntax nodes for the constraints attached to a property.
  // For example, `.minLength(3)`
  let constraints: [ExprSyntax]
}

/// Extracts stored properties from a struct declaration and parses their metadata.
///
/// ## Example
///
/// Input: struct User { let name: String, let age: Int? }
/// Output: [
///   Property(name: "name", type: "String", isOptional: false, guide: nil),
///   Property(name: "age", type: "Int", isOptional: true, guide: nil)
/// ]
private func parseStoredProperties(from structDecl: StructDeclSyntax) throws
  -> [PropertyDescriptor]
{
  let storedMembersDecls = structDecl.memberBlock.members.compactMap { member in
    member.decl.as(VariableDeclSyntax.self)
  }.filter { variableDecl in
    // Only consider stored properties (let/var without getters and without default values)
    variableDecl.bindings.allSatisfy { bindingSyntax in
      bindingSyntax.accessorBlock == nil && bindingSyntax.initializer == nil
    }
    // TODO: Revisit whether properties with default values should be excluded from schema
  }

  // TODO: Handle @Generable with a `description` parameter.

  var propertyDescriptors: [PropertyDescriptor] = []

  for memberDecl in storedMembersDecls {
    for bindingSyntax in memberDecl.bindings {
      guard let identifierSyntax = bindingSyntax.pattern.as(IdentifierPatternSyntax.self) else {
        throw GenerableMacroError(
          message:
            "@Generable does not support complex property patterns (like tuple destructuring). Use simple property declarations like 'let name: String'.",
          id: "unsupportedPropertyPattern"
        )
      }

      guard let typeSyntax = bindingSyntax.typeAnnotation?.type else {
        let propertyName = identifierSyntax.identifier.text
        throw GenerableMacroError(
          message:
            "Property '\(propertyName)' must have an explicit type annotation. Use 'let \(propertyName): Type' instead of relying on type inference.",
          id: "missingTypeAnnotation"
        )
      }

      let propertyName = identifierSyntax.identifier.text
      let isOptional = typeSyntax.is(OptionalTypeSyntax.self)

      try validateNotArrayOfOptional(type: typeSyntax, propertyName: propertyName)

      // Parse @Guide attributes for this property
      let guideDescriptor = parseGuideMacro(for: memberDecl)

      let propertyDescriptor = PropertyDescriptor(
        name: propertyName,
        type: typeSyntax,
        isOptional: isOptional,
        guide: guideDescriptor
      )
      propertyDescriptors.append(propertyDescriptor)
    }
  }

  return propertyDescriptors
}

/// Generates a static schema variable declaration for a Generable type.
///
/// ## Example
///
/// Input: typeName: "User", properties: [Property(name: "name", type: "String", ...)]
/// Output: VariableDeclSyntax for:
///   public static var schema: Schema {
///     .object(name: "User", description: nil, properties: ["name": Schema.Property(...)])
///   }
private func emitSchemaVariable(
  typeName: String,
  properties: [PropertyDescriptor]
) throws -> VariableDeclSyntax {
  var schemaPropExprs: [DictionaryElementSyntax] = []

  for property in properties {
    let propertyName = property.name
    let isOptional = property.isOptional

    try validateNotArrayOfOptional(type: property.type, propertyName: propertyName)

    // Parse @Guide attributes for this property
    let guideInfo = property.guide
    let schemaExpr = emitSchemaExpression(for: property.type, guideInfo: guideInfo)

    let descriptionExpr: ExprSyntax =
      if let desc = guideInfo?.description {
        ExprSyntax(literal: desc)
      } else {
        ExprSyntax("nil")
      }

    let schemaPropExpr = DictionaryElementSyntax(
      key: ExprSyntax(literal: propertyName),
      value: FunctionCallExprSyntax(callee: ExprSyntax("Schema.Property")) {
        LabeledExprSyntax(label: "schema", expression: schemaExpr)
        LabeledExprSyntax(label: "description", expression: descriptionExpr)
        LabeledExprSyntax(label: "isOptional", expression: ExprSyntax(literal: isOptional))
      }
    )

    schemaPropExprs.append(schemaPropExpr)
  }

  return try VariableDeclSyntax("public nonisolated static var schema: Schema") {
    """
    .object(
      name: "\(raw: typeName)",
      description: nil,
      properties: \(DictionaryExprSyntax {
        for schemaPropExpr in schemaPropExprs {
          schemaPropExpr
        }
      })
    )
    """
  }
}

/// Generates a generableContent variable declaration for a Generable type.
///
/// ## Example
///
/// Input: typeName: "User", properties: [PropertyDescriptor(name: "name", type: "String", ...)]
/// Output: VariableDeclSyntax for:
///   public var generableContent: StructuredContent {
///     StructuredContent(kind: .object(["name": self.name.generableContent, ...]))
///   }
private func emitGenerableContentVariable(
  typeName: String,
  properties: [PropertyDescriptor]
) throws -> VariableDeclSyntax {
  var contentProps: [DictionaryElementSyntax] = []

  for property in properties {
    let propertyName = property.name

    let valueExpr: ExprSyntax
    if property.isOptional {
      // Handle optional properties by safely unwrapping
      valueExpr = ExprSyntax(
        "self.\(raw: propertyName)?.generableContent ?? StructuredContent(kind: .null)")
    } else {
      valueExpr = ExprSyntax("self.\(raw: propertyName).generableContent")
    }

    let contentProp = DictionaryElementSyntax(
      key: ExprSyntax(literal: propertyName),
      value: valueExpr
    )

    contentProps.append(contentProp)
  }

  return try VariableDeclSyntax("public nonisolated var generableContent: StructuredContent") {
    """
    StructuredContent(kind: .object(\(DictionaryExprSyntax {
      for contentProp in contentProps {
        contentProp
      }
    })))
    """
  }
}

/// Generates a nested Partial struct for streaming support.
///
/// ## Example
///
/// Input: typeName: "User", properties: [PropertyDescriptor(name: "name", type: "String", ...)]
/// Output: StructDeclSyntax for:
///   public struct Partial: Codable, Sendable {
///     public var name: String.Partial?
///     public var age: Int.Partial?
///
///     public init(name: String.Partial? = nil, age: Int.Partial? = nil) {
///       self.name = name
///       self.age = age
///     }
///   }
private func emitPartialStruct(
  typeName: String,
  properties: [PropertyDescriptor]
) throws -> StructDeclSyntax {
  let partialProperties = try properties.map { property in
    let propertyName = property.name
    let partialType = emitPartialType(for: property.type)
    return try VariableDeclSyntax("public let \(raw: propertyName): \(partialType)")
  }

  return try StructDeclSyntax("public nonisolated struct Partial: Codable, Sendable") {
    for property in partialProperties {
      MemberBlockItemSyntax(decl: property)
    }
  }
}

/// Generates the partial type for a given property type.
///
/// ## Examples
///
/// Input: "String" -> Output: "String.Partial?"
/// Input: "String?" -> Output: "String.Partial?"
/// Input: "[String]" -> Output: "[String].Partial?"
/// Input: "CustomType" -> Output: "CustomType.Partial?"
private func emitPartialType(for type: TypeSyntax) -> TypeSyntax {
  // Handle optional types: T? -> T.Partial?
  if let optionalType = type.as(OptionalTypeSyntax.self) {
    let baseType = optionalType.wrappedType.trimmed.description
    return TypeSyntax("\(raw: baseType).Partial?")
  }

  // Handle base types: T -> T.Partial?
  let baseType = type.trimmed.description
  return TypeSyntax("\(raw: baseType).Partial?")
}

/// Generates a schema expression for a given type with optional constraints.
///
/// ## Example
///
/// Input: type: "String", guideInfo: GuideDescriptor(description: "User name", constraints: [.minLength(3)])
/// Output: ExprSyntax for: .string(constraints: []).withConstraint(.minLength(3))
private func emitSchemaExpression(for type: TypeSyntax, guideInfo: GuideDescriptor? = nil)
  -> ExprSyntax
{
  // Generate base schema without constraints
  let baseSchemaExpr = emitBaseSchemaExpression(for: type)

  // Apply constraints using withConstraint if any exist
  return emitConstrainedSchema(baseSchema: baseSchemaExpr, guideInfo: guideInfo)
}

/// Generates a base schema expression without any constraints.
///
/// ## Example
///
/// Input: type: "String"
/// Output: ExprSyntax for: "String.schema"
private func emitBaseSchemaExpression(for type: TypeSyntax) -> ExprSyntax {
  // Handle optional types
  if let optionalType = type.as(OptionalTypeSyntax.self) {
    return emitBaseSchemaExpression(for: optionalType.wrappedType)
  }

  let typeName = type.trimmed.description
  return ExprSyntax("\(raw: typeName).schema")
}

/// Applies constraints to a base schema using the withConstraint API.
///
/// ## Example
///
/// Input: baseSchema: .string(constraints: []), guideInfo: GuideDescriptor(constraints: [.minLength(3)])
/// Output: ExprSyntax for: .string(constraints: []).withConstraints([.minLength(3)])
private func emitConstrainedSchema(
  baseSchema: ExprSyntax,
  guideInfo: GuideDescriptor?
) -> ExprSyntax {
  guard let guideInfo, !guideInfo.constraints.isEmpty else {
    return baseSchema
  }

  // Generate a single call to withConstraints with all constraints
  // ```
  // .string(constraints: [])
  //   .withConstraints([
  //     Constraint<String>.minLength(3),
  //     Constraint<String>.maxLength(5)
  //   ])
  // ```
  return ExprSyntax(
    FunctionCallExprSyntax(
      callee: MemberAccessExprSyntax(
        base: baseSchema,
        name: "withConstraints"
      )
    ) {
      LabeledExprSyntax(
        expression: ExprSyntax(
          ArrayExprSyntax {
            for constraint in guideInfo.constraints {
              ArrayElementSyntax(expression: constraint)
            }
          }
        ))
    }
  )
}

/// Parses @Guide attributes from a property declaration to extract description and constraints.
///
/// ## Example
///
/// Input: @Guide("User name", .minLength(3)) let name: String
/// Output: GuideDescriptor(
///   description: "User name",
///   constraints: [Constraint<String>.minLength(3)]
/// )
private func parseGuideMacro(for property: VariableDeclSyntax) -> GuideDescriptor? {
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
        return GuideDescriptor(description: description, constraints: constraints)
      }
    }
  }
  return nil
}

/// Generates an initializer from StructuredContent for a Generable type.
///
/// ## Example
///
/// For a struct with properties: name: String, age: Int?, tags: [String]
/// Generates:
///   public init(from structuredContent: StructuredContent) throws {
///     let object = try structuredContent.object
///
///     guard let nameContent = object["name"] else {
///       throw LLMError.generalError("Missing required property: name")
///     }
///     self.name = try String(from: nameContent)
///
///     guard let ageContent = object["age"] else {
///       throw LLMError.generalError("Missing required property: age")
///     }
///     self.age = try Int?(from: ageContent)
///
///     ...
///   }
private func emitStructuredContentInitializer(
  properties: [PropertyDescriptor]
) throws -> InitializerDeclSyntax {
  var bodyItems = [CodeBlockItemSyntax]()

  // First extract the object dictionary if there are properties to initliaze.
  if !properties.isEmpty {
    let objectDecl = CodeBlockItemSyntax(
      item: .decl(
        DeclSyntax(
          try VariableDeclSyntax("let object = try structuredContent.object")
        )
      )
    )
    .with(\.trailingTrivia, .newlines(2))
    bodyItems.append(objectDecl)
  }

  // Then initialize each property
  for (i, property) in properties.enumerated() {
    let propertyName = property.name
    let propertyTypeName = property.type.trimmed.description
    let contentVarName = "\(propertyName)Content"
    let isLastProperty = i == properties.count - 1

    // Generate guard statement to check for missing property
    bodyItems.append(
      CodeBlockItemSyntax(
        item: .stmt(
          StmtSyntax(
            """
            guard let \(raw: contentVarName) = object[\(literal: propertyName)] else {
              throw LLMError.generalError(\(literal: "Missing required property: \(propertyName)"))
            }
            """))))

    // Generate property assignment using Type(from: content)
    bodyItems.append(
      CodeBlockItemSyntax(
        item: .expr(
          ExprSyntax(
            "self.\(raw: propertyName) = try \(raw: propertyTypeName)(from: \(raw: contentVarName))"
          ))
      )
      .with(\.trailingTrivia, isLastProperty ? .newlines(1) : .newlines(2)))
  }

  return try InitializerDeclSyntax(
    "public nonisolated init(from structuredContent: StructuredContent) throws"
  ) {
    for item in bodyItems {
      item
    }
  }
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
      throw GenerableMacroError(
        message:
          "Property '\(propertyName)' cannot be an array of optional types '[\(elementTypeName)?]'. Arrays of optionals are not supported. Consider using a different data structure or making the entire array optional instead.",
        id: "arrayOfOptionalType"
      )
    }
  }
}

/// Metadata about a property extracted from a struct declaration.
private struct PropertyDescriptor {
  /// The name of the property.
  let name: String

  /// The type of the property.
  let type: TypeSyntax

  /// Whether the property is optional.
  let isOptional: Bool

  /// Guide information including description and constraints.
  let guide: GuideDescriptor?
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
  configuration.respectsExistingLineBreaks = true
  configuration.spacesAroundRangeFormationOperators = true

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

struct GenerableMacroError: DiagnosticMessage, Error {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity

  init(message: String, id: String) {
    self.message = message
    self.diagnosticID = MessageID(domain: "GenerableMacro", id: id)
    self.severity = .error
  }
}
