import SwiftDiagnostics
import SwiftFormat
import SwiftOperators
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// TODO: Handle Optional<T> during expansion. Now optionals are assumed to always end with "?".

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
    if let structDecl = declaration.as(StructDeclSyntax.self) {
      return try expandStruct(structDecl, type: type, context: context)
    } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      return try expandEnum(enumDecl, type: type, context: context)
    } else {
      throw GenerableMacroError(
        message: "@Generable can only be applied to structs or enums",
        id: "notStructOrEnum"
      )
    }
  }

  private static func expandStruct(
    _ structDecl: StructDeclSyntax,
    type: some TypeSyntaxProtocol,
    context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
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

      try emitGenerableContentVariable(properties: propertyDescriptors)
        .with(\.trailingTrivia, .newlines(2))

      try emitStructuredContentInitializer(properties: propertyDescriptors)
    }

    return [extensionDecl.formatted()]
  }

  private static func expandEnum(
    _ enumDecl: EnumDeclSyntax,
    type: some TypeSyntaxProtocol,
    context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let typeName = type.trimmed.description
    let cases = try parseEnumCases(from: enumDecl)

    let extensionDecl = try ExtensionDeclSyntax(
      "nonisolated extension \(type.trimmed): SwiftAI.Generable"
    ) {
      try emitEnumPartial(typeName: typeName, cases: cases)
        .with(\.trailingTrivia, .newlines(2))

      try emitEnumSchemaVariable(typeName: typeName, cases: cases)
        .with(\.trailingTrivia, .newlines(2))

      try emitEnumGenerableContentVariable(cases: cases)
        .with(\.trailingTrivia, .newlines(2))

      try emitEnumStructuredContentInitializer(cases: cases)
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
///   public struct Partial: GenerableContentConvertible, Codable, Sendable {
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
  // Convert properties to partial property descriptors (all properties become optional)
  let partialPropertyDescriptors = properties.map { property in
    PropertyDescriptor(
      name: property.name,
      type: emitPartialType(for: property.type),
      isOptional: true,  // All partial properties are optional
      guide: property.guide
    )
  }

  let partialProperties = try partialPropertyDescriptors.map { property in
    let propertyName = property.name
    let partialType = property.type
    return try VariableDeclSyntax("public let \(raw: propertyName): \(partialType)")
  }

  return try StructDeclSyntax(
    "public nonisolated struct Partial: SwiftAI.GenerableContentConvertible, Sendable"
  ) {
    for property in partialProperties {
      MemberBlockItemSyntax(decl: property)
    }

    try emitGenerableContentVariable(properties: partialPropertyDescriptors)
      .with(\.trailingTrivia, .newlines(2))
      .with(\.leadingTrivia, .newlines(2))

    try emitStructuredContentInitializer(properties: partialPropertyDescriptors)
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
    let isOptional = property.type.is(OptionalTypeSyntax.self)

    if isOptional {
      // For optional properties, use if let instead of guard
      bodyItems.append(
        CodeBlockItemSyntax(
          item: .stmt(
            StmtSyntax(
              """
              if let \(raw: contentVarName) = object[\(literal: propertyName)] {
                self.\(raw: propertyName) = try \(raw: propertyTypeName)(from: \(raw: contentVarName))
              } else {
                self.\(raw: propertyName) = nil
              }
              """))
        )
        .with(\.trailingTrivia, isLastProperty ? .newlines(1) : .newlines(2)))
    } else {
      // For required properties, use guard statement
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
  }

  return try InitializerDeclSyntax(
    "public nonisolated init(from structuredContent: StructuredContent) throws"
  ) {
    for item in bodyItems {
      item
    }
  }
}

/// Provides a programmatic representation of an enum case and its associated values.
private struct EnumCaseDescriptor {
  /// The case name.
  let name: String

  /// The associated values for the case.
  let parameters: [EnumParameter]

  var hasAssociatedValues: Bool {
    !parameters.isEmpty
  }
}

/// Represents an associated value parameter for an enum case.
private struct EnumParameter {
  let label: String?  // nil for unnamed parameters
  let type: String
  let index: Int

  /// The effective label to use for this parameter in generated code.
  /// For labeled parameters, returns the label.
  /// For unlabeled parameters, returns "value" for the first parameter, "value", "value1", etc. for subsequent ones.
  var effectiveLabel: String {
    label ?? (index == 0 ? "value" : "value\(index)")
  }
}

/// Parses enum cases from an enum declaration.
///
/// ## Example
///
/// Input: enum Status { case active; case inactive; case pending }
/// Output: [EnumCaseDescriptor(name: "active", parameters: []), ...]
///
/// Input: enum Result { case success(value: String); case failure(Error) }
/// Output: [EnumCaseDescriptor(name: "success", parameters: [EnumParameter(label: "value", type: "String")]), ...]
private func parseEnumCases(from enumDecl: EnumDeclSyntax) throws -> [EnumCaseDescriptor] {
  return enumDecl.memberBlock.members
    .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
    .flatMap { $0.elements }
    .map { enumCase in
      let parameters = parseEnumParameters(from: enumCase.parameterClause)
      return EnumCaseDescriptor(name: enumCase.name.text, parameters: parameters)
    }
}

/// Parses parameters from an enum case parameter clause.
///
/// ## Example
///
/// Input: case success(value: String)
/// Output: [EnumParameter(label: "value", type: "String", index: 0)]
///
/// Input: case pair(String, Int)
/// Output: [EnumParameter(label: nil, type: "String", index: 0), EnumParameter(label: nil, type: "Int", index: 1)]
private func parseEnumParameters(from clause: EnumCaseParameterClauseSyntax?) -> [EnumParameter] {
  guard let clause = clause else {
    return []
  }

  return clause.parameters.enumerated().map { index, param in
    EnumParameter(
      label: param.firstName?.text,
      type: param.type.trimmedDescription,
      index: index
    )
  }
}

/// Transforms an enum case to its Partial equivalent by making all associated value parameters optional.
///
/// ## Example
///
/// Input: EnumCaseDescriptor(name: "success", parameters: [EnumParameter(label: "value", type: "String", index: 0)])
/// Output: EnumCaseDescriptor(name: "success", parameters: [EnumParameter(label: "value", type: "String.Partial?", index: 0)])
private func transformEnumCaseToPartial(_ enumCase: EnumCaseDescriptor) -> EnumCaseDescriptor {
  let partialParameters = enumCase.parameters.map { param in
    let paramTypeSyntax = TypeSyntax(stringLiteral: param.type)
    let partialTypeSyntax = emitPartialType(for: paramTypeSyntax)
    let partialTypeString = partialTypeSyntax.trimmed.description

    return EnumParameter(
      label: param.label,
      type: partialTypeString,
      index: param.index
    )
  }

  return EnumCaseDescriptor(name: enumCase.name, parameters: partialParameters)
}

/// Generates Partial type for enums.
///
/// For simple enums without associated values, generates a typealias.
/// For enums with associated values, generates a nested Partial enum.
///
/// ## Example (simple enum)
///
/// Output:
///   public typealias Partial = Self
///
/// ## Example (enum with associated values)
///
/// Output:
///   public enum Partial: GenerableContentConvertible, Sendable {
///     case success(value: String.Partial?)
///     case failure(error: String.Partial?)
///
///     public var generableContent: StructuredContent { ... }
///     public init(from structuredContent: StructuredContent) throws { ... }
///   }
private func emitEnumPartial(
  typeName: String,
  cases: [EnumCaseDescriptor]
) throws -> DeclSyntax {
  let hasAnyAssociatedValues = cases.contains { $0.hasAssociatedValues }
  if !hasAnyAssociatedValues {
    // Simple enum without associated values - use typealias
    return DeclSyntax(try TypeAliasDeclSyntax("public typealias Partial = Self"))
  }

  // Generate enum case declarations with partial parameters.
  let partialCases = cases.map { transformEnumCaseToPartial($0) }
  let partialCaseDecls = partialCases.map { partialCase in
    if !partialCase.hasAssociatedValues {
      return DeclSyntax("case \(raw: partialCase.name)")
    }
    let caseSignature = partialCase.parameters.map { param in
      if let label = param.label {
        return "\(label): \(param.type)"
      } else {
        return param.type
      }
    }.joined(separator: ", ")
    return DeclSyntax("case \(raw: partialCase.name)(\(raw: caseSignature))")
  }

  return DeclSyntax(
    try EnumDeclSyntax(
      "public nonisolated enum Partial: SwiftAI.GenerableContentConvertible, Sendable"
    ) {
      for caseItem in partialCaseDecls {
        MemberBlockItemSyntax(decl: caseItem)
          .with(\.trailingTrivia, .newlines(1))
      }

      try emitEnumGenerableContentVariable(cases: partialCases)
        .with(\.trailingTrivia, .newlines(2))
        .with(\.leadingTrivia, .newlines(2))

      try emitEnumStructuredContentInitializer(cases: partialCases)
    }
  )
}

/// Generates a schema variable for enums using anyOf.
///
/// For enums without associated values, uses constant strings.
/// For enums with associated values, uses objects with a "type" discriminator field.
///
/// ## Example (simple enum)
///
/// Output:
///   public static var schema: Schema {
///     .anyOf(
///       name: "Status",
///       description: nil,
///       schemas: [
///         .string(constraints: [.constant("active")]),
///         .string(constraints: [.constant("inactive")])
///       ]
///     )
///   }
///
/// ## Example (enum with associated values)
///
/// Output:
///   public static var schema: Schema {
///     .anyOf(
///       name: "Result",
///       description: nil,
///       schemas: [
///         .object(
///           name: nil,
///           description: nil,
///           properties: [
///             "type": Schema.Property(schema: .string(constraints: [.constant("success")]), description: nil, isOptional: false),
///             "value": Schema.Property(schema: String.schema, description: nil, isOptional: false)
///           ]
///         ),
///         .object(
///           name: nil,
///           description: nil,
///           properties: [
///             "type": Schema.Property(schema: .string(constraints: [.constant("failure")]), description: nil, isOptional: false),
///             "error": Schema.Property(schema: Error.schema, description: nil, isOptional: false)
///           ]
///         )
///       ]
///     )
///   }
private func emitEnumSchemaVariable(
  typeName: String,
  cases: [EnumCaseDescriptor]
) throws -> VariableDeclSyntax {
  var caseSchemaExprs = [ArrayElementSyntax]()

  let hasAnyAssociatedValues = cases.contains { $0.hasAssociatedValues }

  for enumCase in cases {
    if hasAnyAssociatedValues {
      // If enum has any associated values, all cases use object schema with "type" discriminator
      var properties = [DictionaryElementSyntax]()

      // Add the "type" discriminator field
      let typeProperty = DictionaryElementSyntax(
        key: ExprSyntax(literal: "type"),
        value: ExprSyntax(
          """
          Schema.Property(
            schema: .string(constraints: [.constant(\(literal: enumCase.name))]),
            description: nil,
            isOptional: false
          )
          """)
      )
      properties.append(typeProperty)

      // Add properties for each associated value
      for param in enumCase.parameters {
        let isOptional = param.type.hasSuffix("?")
        let propertySchema = DictionaryElementSyntax(
          key: ExprSyntax(literal: param.effectiveLabel),
          value: ExprSyntax(
            """
            Schema.Property(
              schema: \(raw: param.type).schema,
              description: nil,
              isOptional: \(raw: isOptional ? "true" : "false")
            )
            """)
        )
        properties.append(propertySchema)
      }

      let objectSchema = ExprSyntax(
        """
        .object(
          name: \(literal: "\(enumCase.name)Discriminator"),
          description: nil,
          properties: \(DictionaryExprSyntax {
            for property in properties {
              property
            }
          })
        )
        """)
      caseSchemaExprs.append(ArrayElementSyntax(expression: objectSchema))
    } else {
      // For simple enums without any associated values, use constant strings
      let schemaExpr = ExprSyntax(".string(constraints: [.constant(\(literal: enumCase.name))])")
      caseSchemaExprs.append(ArrayElementSyntax(expression: schemaExpr))
    }
  }

  // TODO: Add description if set in @Generable.
  return try VariableDeclSyntax("public nonisolated static var schema: Schema") {
    """
    .anyOf(
      name: \(literal: typeName),
      description: nil,
      schemas: \(ArrayExprSyntax {
        for schemaExpr in caseSchemaExprs {
          schemaExpr
        }
      })
    )
    """
  }
}

/// Generates a generableContent variable for enums.
///
/// For simple enums without associated values, returns string content.
/// For enums with associated values, returns object content with "type" discriminator.
///
/// ## Example (simple enum)
///
/// Output:
///   public var generableContent: StructuredContent {
///     switch self {
///     case .active:
///       return StructuredContent(kind: .string("active"))
///     case .inactive:
///       return StructuredContent(kind: .string("inactive"))
///     }
///   }
///
/// ## Example (enum with associated values)
///
/// Output:
///   public var generableContent: StructuredContent {
///     switch self {
///     case .success(let value):
///       return StructuredContent(kind: .object([
///         "type": StructuredContent(kind: .string("success")),
///         "value": value.generableContent
///       ]))
///     case .failure(let error):
///       return StructuredContent(kind: .object([
///         "type": StructuredContent(kind: .string("failure")),
///         "error": error.generableContent
///       ]))
///     }
///   }
private func emitEnumGenerableContentVariable(
  cases: [EnumCaseDescriptor]
) throws -> VariableDeclSyntax {
  let hasAnyAssociatedValues = cases.contains { $0.hasAssociatedValues }

  var switchCaseItems = [CodeBlockItemSyntax]()
  for enumCase in cases {
    if hasAnyAssociatedValues {
      // If enum has any associated values, all cases use object format with "type" discriminator
      if enumCase.hasAssociatedValues {
        // Generate pattern with let bindings for associated values
        let bindings = enumCase.parameters.map { param in
          "let \(param.effectiveLabel)"
        }.joined(separator: ", ")

        // Generate object properties
        var properties: [String] = []
        properties.append("\"type\": StructuredContent(kind: .string(\"\(enumCase.name)\"))")

        for param in enumCase.parameters {
          properties.append("\"\(param.effectiveLabel)\": \(param.effectiveLabel).generableContent")
        }

        let propertiesStr = properties.joined(separator: ", ")

        switchCaseItems.append(
          CodeBlockItemSyntax(
            item: .stmt(
              StmtSyntax(
                """
                case .\(raw: enumCase.name)(\(raw: bindings)):
                  return StructuredContent(kind: .object([\(raw: propertiesStr)]))
                """
              )
            )
          )
        )
      } else {
        // Simple case, but still use object format with just "type" field
        switchCaseItems.append(
          CodeBlockItemSyntax(
            item: .stmt(
              StmtSyntax(
                """
                case .\(raw: enumCase.name):
                  return StructuredContent(
                    kind: .object([
                      "type": StructuredContent(kind: .string(\(literal: enumCase.name)))
                    ]
                  )
                )
                """
              )
            )
          )
        )
      }
    } else {
      // Purely simple enum - use string format for all cases
      switchCaseItems.append(
        CodeBlockItemSyntax(
          item: .stmt(
            StmtSyntax(
              """
              case .\(raw: enumCase.name):
                return StructuredContent(kind: .string(\(literal: enumCase.name)))
              """
            )
          )
        )
      )
    }
  }

  return try VariableDeclSyntax("public nonisolated var generableContent: StructuredContent") {
    """
    switch self {
    \(CodeBlockItemListSyntax(switchCaseItems))
    }
    """
  }
}

/// Generates an initializer from StructuredContent for enums.
private func emitEnumStructuredContentInitializer(
  cases: [EnumCaseDescriptor]
) throws -> InitializerDeclSyntax {
  let hasAnyAssociatedValues = cases.contains { $0.hasAssociatedValues }
  if hasAnyAssociatedValues {
    return try emitEnumObjectBasedInitializer(cases: cases)
  } else {
    return try emitEnumStringBasedInitializer(cases: cases)
  }
}

/// Generates a string-based initializer for simple enums without associated values.
///
/// ## Example
///
/// Output:
///   public init(from structuredContent: StructuredContent) throws {
///     let stringValue = try structuredContent.string
///     switch stringValue {
///     case "active":
///       self = .active
///     case "inactive":
///       self = .inactive
///     default:
///       throw LLMError.generalError("Unknown enum case: \(stringValue)")
///     }
///   }
private func emitEnumStringBasedInitializer(
  cases: [EnumCaseDescriptor]
) throws -> InitializerDeclSyntax {
  var switchCaseItems = [CodeBlockItemSyntax]()
  for enumCase in cases {
    switchCaseItems.append(
      CodeBlockItemSyntax(
        item: .stmt(
          StmtSyntax(
            """
            case \(literal: enumCase.name):
              self = .\(raw: enumCase.name)
            """
          )
        )
      ).with(\.trailingTrivia, .newlines(1))
    )
  }

  // Add default case for unknown values
  switchCaseItems.append(
    CodeBlockItemSyntax(
      item: .stmt(
        StmtSyntax(
          """
          default:
            throw LLMError.generalError("Unknown enum case: \\(stringValue)")
          """
        )
      )
    )
  )

  return try InitializerDeclSyntax(
    "public nonisolated init(from structuredContent: StructuredContent) throws"
  ) {
    """
    let stringValue = try structuredContent.string
    switch stringValue {
    \(CodeBlockItemListSyntax(switchCaseItems))
    }
    """
  }
}

/// Generates an object-based initializer for enums with associated values.
///
/// Parses object format with "type" discriminator field.
private func emitEnumObjectBasedInitializer(
  cases: [EnumCaseDescriptor]
) throws -> InitializerDeclSyntax {
  var switchCaseItems = [CodeBlockItemSyntax]()

  // Generate switch case for each enum case
  for enumCase in cases {
    if enumCase.hasAssociatedValues {
      // Cases with associated values - extract each parameter
      var caseBodyLines = [String]()

      // Extract associated value parameters
      for param in enumCase.parameters {
        let isOptional = param.type.hasSuffix("?")
        let effectiveLabel = param.effectiveLabel

        if isOptional {
          // Optional parameter - use if let
          caseBodyLines.append(
            """
            let \(effectiveLabel): \(param.type) = try {
              if let \(effectiveLabel)Content = object[\"\(effectiveLabel)\"] {
                return try \(param.type)(from: \(effectiveLabel)Content)
              } else {
                return nil
              }
            }()
            """)
        } else {
          // Required parameter - use guard
          caseBodyLines.append(
            """
            guard let \(param.effectiveLabel)Content = object[\"\(param.effectiveLabel)\"] else {
              throw LLMError.generalError("Missing required property: \(param.effectiveLabel)")
            }
            let \(param.effectiveLabel) = try \(param.type)(from: \(param.effectiveLabel)Content)
            """)
        }
      }

      // Generate enum case construction
      let associatedValues = enumCase.parameters.map { param in
        if let label = param.label {
          return "\(label): \(param.effectiveLabel)"
        } else {
          return param.effectiveLabel
        }
      }.joined(separator: ", ")

      caseBodyLines.append("self = .\(enumCase.name)(\(associatedValues))")

      let caseBody = caseBodyLines.joined(separator: "\n")

      switchCaseItems.append(
        CodeBlockItemSyntax(
          item: .stmt(
            StmtSyntax(
              """
              case \(literal: enumCase.name):
              \(raw: caseBody)
              """
            )
          )
        ).with(\.trailingTrivia, .newlines(1))
      )
    } else {
      // Simple case without associated values
      switchCaseItems.append(
        CodeBlockItemSyntax(
          item: .stmt(
            StmtSyntax(
              """
              case \(literal: enumCase.name):
                self = .\(raw: enumCase.name)
              """
            )
          )
        ).with(\.trailingTrivia, .newlines(1))
      )
    }
  }

  // Add default case for unknown enum values
  switchCaseItems.append(
    CodeBlockItemSyntax(
      item: .stmt(
        StmtSyntax(
          """
          default:
            throw LLMError.generalError("Unknown enum case: \\(type)")
          """
        )
      )
    )
  )

  return try InitializerDeclSyntax(
    "public nonisolated init(from structuredContent: StructuredContent) throws"
  ) {
    """
    let object = try structuredContent.object
    guard let typeContent = object["type"] else {
      throw LLMError.generalError("Missing 'type' discriminator for enum")
    }
    let type = try typeContent.string

    switch type {
    \(CodeBlockItemListSyntax(switchCaseItems))
    }
    """
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
