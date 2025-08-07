import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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
                let schemaType = makeSchemaForType(type)

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

    private static func makeSchemaForType(_ type: TypeSyntax) -> String {
        let typeName = type.trimmed.description

        // Handle optional types
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            return makeSchemaForType(optionalType.wrappedType)
        }

        // Handle array types
        if let arrayType = type.as(ArrayTypeSyntax.self) {
            let elementSchema = makeSchemaForType(arrayType.element)
            return ".array(items: \(elementSchema), metadata: nil)"
        }

        // Handle basic types
        switch typeName {
        case "String":
            return ".string(constraints: [], metadata: nil)"
        case "Int":
            return ".integer(constraints: [], metadata: nil)"
        case "Double":
            return ".number(constraints: [], metadata: nil)"
        case "Bool":
            return ".boolean(metadata: nil)"
        default:
            // For custom types, assume they conform to Generable and reference their schema
            return "\(typeName).schema"
        }
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
