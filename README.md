# swift-foldable

Use this package when you need to reduce every value of a generic struct's or enum's type parameter to one result, without writing the traversal by hand. Attach `@Foldable` to the declaration and it generates `fold` and `foldMap`. To transform the elements and rebuild the value, use swift-functor instead. To fold a recursive structure layer by layer, use swift-catamorphism.

## Laws

- `fold` combines each element exactly once, in declaration order. For a struct, that means stored properties from top to bottom. For an enum, it means the matched case's payloads from left to right. Inside a field, an array is folded in index order, an optional only when it holds a value, and a tuple from left to right.
- A field or payload whose type does not mention the type parameter contributes nothing. A case with no elements returns the initial value unchanged.
- `foldMap(monoid, transform)` equals `fold(monoid.identity) { monoid.combining($0, transform($1)) }`, with the `Algebra.Monoid<Result>` passed in. Because a monoid's combining is associative and its identity is neutral, the result does not depend on how the elements are grouped.
- Expansion fails with a compile-time error at the attribute in these cases: the declaration is not a struct or enum; it does not have exactly one type parameter; that parameter has a constraint or the declaration has a `where` clause; or the type parameter appears somewhere other than directly, inside an array, inside an optional, or inside a tuple.
