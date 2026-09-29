import Foldable_Macro
import Testing

@Foldable
private enum Few<Element> {
    case none
    case one(Element)
    case two(Element, Element)
}

@Suite
struct `Foldable boundaries` {
    @Test
    func `a case without elements returns the initial value`() {
        #expect(Few<String>.none.fold("start", +) == "start")
    }

    @Test
    func `every element of a case is folded in order`() {
        #expect(Few.one("A").fold("", +) == "A")
        #expect(Few.two("A", "B").fold("", +) == "AB")
    }
}
