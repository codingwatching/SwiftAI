import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw GenerableMacroError.notAStruct
        }

        let properties = try makeProperties(from: structDecl)

        let schemaProperty = DeclSyntax(
            """
            public static var schema: Schema {
              .object(properties: [\(raw: properties)], metadata: nil)
            }
            """
        )

        let extensionDecl = try ExtensionDeclSyntax(
            "extension \(type.trimmed): Generable"
        ) {
            schemaProperty
        }

        return [extensionDecl]
    }

    private static func makeProperties(from structDecl: StructDeclSyntax) throws -> String {
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

        var propertyEntries: [String] = []

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
                let schemaType = makeSchemaForType(type, guideInfo: guideInfo)

                // FIXME: Use a more structured way to build the schema that outputs well formatted Swift code.
                let propertyEntry = """
                    "\(propertyName)": Schema.Property(
                      schema: \(schemaType),
                      isOptional: \(isOptional)
                    )
                    """
                propertyEntries.append(propertyEntry)
            }
        }

        return propertyEntries.joined(separator: ",\n      ")
    }

    private static func makeSchemaForType(_ type: TypeSyntax, guideInfo: GuideInfo? = nil) -> String
    {
        let typeName = type.trimmed.description

        // Handle optional types
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            return makeSchemaForType(optionalType.wrappedType, guideInfo: guideInfo)
        }

        // Handle array types
        if let arrayType = type.as(ArrayTypeSyntax.self) {
            let elementSchema = makeSchemaForType(arrayType.element)
            let metadata = makeMetadata(from: guideInfo)
            return ".array(items: \(elementSchema), constraints: [], metadata: \(metadata))"
        }

        // Handle basic types with constraints and metadata
        let metadata = makeMetadata(from: guideInfo)

        switch typeName {
        case "String":
            return ".string(constraints: [], metadata: \(metadata))"
        case "Int":
            return ".integer(constraints: [], metadata: \(metadata))"
        case "Double":
            return ".number(constraints: [], metadata: \(metadata))"
        case "Bool":
            return ".boolean(metadata: \(metadata))"
        default:
            // For custom types, assume they conform to Generable and reference their schema
            return "\(typeName).schema"
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

    private static func makeMetadata(from guideInfo: GuideInfo?) -> String {
        guard let guideInfo = guideInfo else {
            return "nil"
        }

        return "Schema.Metadata(description: \"\(guideInfo.description)\")"
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
