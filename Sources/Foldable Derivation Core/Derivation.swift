public import SwiftSyntax
import SwiftSyntaxBuilder

public enum Derivation {
    public static func expansion(of structure: StructDeclSyntax) -> [DeclSyntax] {
        guard
            let generic = structure.genericParameterClause,
            generic.parameters.count == 1,
            let element = generic.parameters.first?.name.text
        else { return [] }

        let fields = structure.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .flatMap(\.bindings)
            .compactMap { binding -> String? in
                guard
                    binding.typeAnnotation?.type.trimmedDescription == element,
                    let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                else { return nil }
                return name
            }

        let reductions = fields.map {
            "result = combine(result, self.\($0))"
        }.joined(separator: "\n")

        return ["""
            func fold<Result>(
                _ initial: Result,
                _ combine: (Result, \(raw: element)) -> Result
            ) -> Result {
                var result = initial
                \(raw: reductions)
                return result
            }
            """]
    }
}
