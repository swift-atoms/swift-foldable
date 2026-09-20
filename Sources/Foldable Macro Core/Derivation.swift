import Type_Algebra_Syntax
public import SwiftSyntax
import SwiftSyntaxBuilder

public enum Derivation {
    private static func reduce(_ type: Type.Syntax.Expression, value: String, parameter: String) throws -> String {
        try Type.Syntax.Traversal.interpret(type, value: value, parameter: parameter,
            constant: { _, _ in "" },
            transform: { "result = combine(result, \($0))" },
            collection: { optional, value, binding, body in
                optional ? "if let \(binding) = \(value) { \(body) }" : "for \(binding) in \(value) { \(body) }"
            },
            product: { _, parts, _ in parts.map { $0.1 }.joined(separator: "\n") })
    }
    private static func members(access: String, parameter: String, body: String) -> [DeclSyntax] {
        [DeclSyntax(stringLiteral: """
            \(access)func fold<Result>(_ initial: Result, _ combine: (Result, \(parameter)) -> Result) -> Result {
                var result = initial
                \(body)
                return result
            }
            """), DeclSyntax(stringLiteral: """
            \(access)func foldMap<Result>(_ monoid: Algebra::Algebra.Monoid<Result>, _ transform: (\(parameter)) -> Result) -> Result {
                fold(monoid.identity) { monoid.combining($0, transform($1)) }
            }
            """)]
    }
    public static func expansion(of structure: StructDeclSyntax) -> [DeclSyntax] {
        do {
            let shape = try Type.Syntax.Product(structure, arity: 1, reconstructing: false)
            let body = try shape.fields.enumerated().map { try reduce($0.element, value: "self.\(shape.properties.fields[$0.offset].name)", parameter: shape.parameters[0]) }.joined(separator: "\n")
            return members(access: shape.access, parameter: shape.parameters[0], body: body)
        } catch { return [DeclSyntax(stringLiteral: "#error(\(String(reflecting: String(describing: error))))")] }
    }
    public static func expansion(of enumeration: EnumDeclSyntax) -> [DeclSyntax] {
        do {
            guard let clause = enumeration.genericParameterClause, clause.parameters.count == 1,
                let parameter = clause.parameters.first, parameter.inheritedType == nil, enumeration.genericWhereClause == nil else {
                throw Type.Failure("@Foldable requires one unconstrained type parameter")
            }
            let arms = try Type.Syntax.Recursion.elements(of: enumeration).map { item -> String in
                let payloads = Type.Syntax.Recursion.parameters(of: item)
                let body = try payloads.enumerated().map {
                    try reduce(Type.Syntax.Expression($0.element.type, parameters: [parameter.name.text]), value: "value\($0.offset)", parameter: parameter.name.text)
                }.filter { !$0.isEmpty }.joined(separator: "\n")
                let pattern = payloads.isEmpty ? ".\(item.name.text)" : "let .\(item.name.text)(\(payloads.indices.map { "value\($0)" }.joined(separator: ", ")))"
                // Constant payloads still bind; silence their intentional absence from the fold.
                let unused = payloads.enumerated().filter { Type.Syntax.Expression($0.element.type, parameters: [parameter.name.text]).polarity(of: parameter.name.text).isEmpty }.map { "_ = value\($0.offset)" }.joined(separator: "\n")
                return "case \(pattern): \(unused)\n\(body.isEmpty ? "break" : body)"
            }.joined(separator: "\n")
            return members(access: Type.Syntax.Recursion.access(of: enumeration), parameter: parameter.name.text, body: "switch self { \(arms) }")
        } catch { return [DeclSyntax(stringLiteral: "#error(\(String(reflecting: String(describing: error))))")] }
    }
}
