@attached(member, names: arbitrary)
public macro Foldable() = #externalMacro(
    module: "Foldable_Macro_Plugin",
    type: "Macro"
)
