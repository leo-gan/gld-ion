from runtime.doc import K_INT, K_STRUCT, K_SYMBOL, IonDoc
from runtime.symtab import Catalog
from wire.text import decode_text


def fail(msg: String) raises:
    raise Error(msg)


def parse(text: String) raises -> IonDoc:
    var raw = text.as_bytes()
    var cat = Catalog()
    return decode_text(raw, cat)


def main() raises:
    var doc = parse("$ion_1_1\n(:$ion set_symbols \"foo\" \"bar\")\nfoo\n")
    if len(doc.top) != 1 or doc.nodes[doc.top[0]].kind != K_SYMBOL:
        fail("symbol kind")
    if doc.sym_text(doc.nodes[doc.top[0]].a) != "foo":
        fail("symbol foo")
    doc = parse(
        "$ion_1_1\n(:$ion set_macros (point {x: (:?), y: (:? 0)}))\n(:point 2 3)\n"
    )
    if len(doc.top) != 1 or doc.nodes[doc.top[0]].kind != K_STRUCT:
        fail("point kind")
    if doc.nodes[doc.top[0]].nchild != 2:
        fail("point fields")
    var x = doc.child_at(doc.top[0], 0)
    var y = doc.child_at(doc.top[0], 1)
    if doc.nodes[x].kind != K_INT or doc.nodes[y].kind != K_INT:
        fail("point ints")
    if Int(doc.limbs[doc.nodes[x].a]) != 2 or Int(doc.limbs[doc.nodes[y].a]) != 3:
        fail("point values")
    doc = parse(
        "$ion_1_1\n(:$ion set_macros (point {x: (:?), y: (:? 0)}))\n(:point 5 (:))\n"
    )
    if doc.nodes[doc.top[0]].nchild != 2:
        fail("default fields")
    y = doc.child_at(doc.top[0], 1)
    if doc.nodes[y].kind != K_INT or doc.nodes[y].b != 0:
        fail("default zero")
    print("ok")
