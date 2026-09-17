import Foldable_Macro
import Testing

@Foldable
private struct Two<Element> {
    var first: Element
    var second: Element
}

@Test
func `derived fold preserves declaration order`() {
    let values = Two(first: "A", second: "B")

    #expect(values.fold("", +) == "AB")
}
