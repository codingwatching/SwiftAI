import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct GuideMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // For peer macros, we don't generate any additional declarations
        // The @Guide macro is purely for metadata collection during @Generable expansion
        return []
    }
}