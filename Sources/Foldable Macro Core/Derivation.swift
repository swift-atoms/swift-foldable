import Type_Algebra_Syntax
public import SwiftSyntax
import SwiftSyntaxBuilder

public enum Derivation {
    private static func reduce(_ type: TypeExpression, value: String, depth: Int = 0) throws -> String {
        switch type {
        case .constant: return ""
        case .parameter: return "result = combine(result, \(value))"
        case .array(let element):
            return "for element\(depth) in \(value) { \(try reduce(element, value: "element\(depth)", depth: depth + 1)) }"
        case .optional(let element):
            return "if let element\(depth) = \(value) { \(try reduce(element, value: "element\(depth)", depth: depth + 1)) }"
        case .tuple(let coordinates):
            return try coordinates.enumerated().map { try reduce($0.element.type, value: "(\(value)).\($0.offset)", depth: depth + 1) }.joined(separator: "\n")
        case .arrow, .unsupported: throw AlgebraDiagnostic("@Foldable requires polynomial occurrences; functions and unknown constructors cannot be enumerated")
        }
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
            let shape = try GenericProduct(structure, arity: 1, reconstructing: false)
            let body = try shape.fields.enumerated().map { try reduce($0.element, value: "self.\(shape.properties.fields[$0.offset].name)") }.joined(separator: "\n")
            return members(access: shape.access, parameter: shape.parameters[0], body: body)
        } catch { return [DeclSyntax(stringLiteral: "#error(\(String(reflecting: String(describing: error))))")] }
    }
    public static func expansion(of enumeration: EnumDeclSyntax) -> [DeclSyntax] {
        do {
            guard let clause = enumeration.genericParameterClause, clause.parameters.count == 1,
                let parameter = clause.parameters.first, parameter.inheritedType == nil, enumeration.genericWhereClause == nil else {
                throw AlgebraDiagnostic("@Foldable requires one unconstrained type parameter")
            }
            let arms = try RecursiveShape.elements(of: enumeration).map { item -> String in
                let payloads = RecursiveShape.parameters(of: item)
                let body = try payloads.enumerated().map {
                    try reduce(TypeExpression($0.element.type, parameters: [parameter.name.text]), value: "value\($0.offset)")
                }.filter { !$0.isEmpty }.joined(separator: "\n")
                let pattern = payloads.isEmpty ? ".\(item.name.text)" : "let .\(item.name.text)(\(payloads.indices.map { "value\($0)" }.joined(separator: ", ")))"
                // Constant payloads still bind; silence their intentional absence from the fold.
                let unused = payloads.enumerated().filter { TypeExpression($0.element.type, parameters: [parameter.name.text]).polarity(of: parameter.name.text).isEmpty }.map { "_ = value\($0.offset)" }.joined(separator: "\n")
                return "case \(pattern): \(unused)\n\(body.isEmpty ? "break" : body)"
            }.joined(separator: "\n")
            return members(access: RecursiveShape.access(of: enumeration), parameter: parameter.name.text, body: "switch self { \(arms) }")
        } catch { return [DeclSyntax(stringLiteral: "#error(\(String(reflecting: String(describing: error))))")] }
    }
}
