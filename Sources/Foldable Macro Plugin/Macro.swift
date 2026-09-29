public import SwiftSyntax
public import SwiftSyntaxMacros
import Foldable_Macro_Core

public struct Macro: MemberMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if let enumeration = declaration.as(EnumDeclSyntax.self) { return Derivation.expansion(of: enumeration) }
        guard let declaration = declaration.as(StructDeclSyntax.self) else {
            throw MacroExpansionErrorMessage(
                "@Foldable applies to a generic struct or enum declaration."
            )
        }
        return Derivation.expansion(of: declaration)
    }
}
