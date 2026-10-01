from runtime.doc import K_BOOL, K_INT, K_LIST, K_STRING, K_STRUCT
from runtime.symtab import Catalog
from wire.text import decode_text


def fail(msg: String) raises:
    print(msg)
    raise Error(msg)


def main() raises:
    var cat = Catalog()
    var doc = decode_text(String("{a:1, b:[true, \"hi\"]}").as_bytes(), cat)
    if len(doc.top) != 1 or doc.nodes[doc.top[0]].kind != K_STRUCT:
        fail("struct")
    if doc.nodes[doc.child_at(doc.top[0], 0)].kind != K_INT:
        fail("int")
    var b = doc.child_at(doc.top[0], 1)
    if doc.nodes[b].kind != K_LIST or doc.nodes[doc.child_at(b, 0)].kind != K_BOOL:
        fail("list")
    if doc.text_at(doc.child_at(b, 1)) != "hi":
        fail("str")
    var n = decode_text(String("null.int").as_bytes(), cat)
    if n.nodes[n.top[0]].a != K_INT:
        fail("null")
    var ts = decode_text(String("2007-02-23T12:14:33.079-08:00").as_bytes(), cat)
    if ts.nodes[ts.top[0]].kind != 6:
        fail("ts")
    var when = ts.times[ts.nodes[ts.top[0]].a]
    if when.hour != 12 or when.off != -480 or when.unknown:
        fail("ts fields")
    var dec = decode_text(String("-0.00").as_bytes(), cat)
    var dn = dec.nodes[dec.top[0]]
    if dn.kind != 5 or dn.c != 1 or dn.d != -2:
        fail("dec")
    var sym = decode_text(String("$ion_1_0\n$ion_symbol_table::{symbols:[\"foo\"]}\n$10\n").as_bytes(), cat)
    if len(sym.top) != 1 or sym.sym_text(sym.nodes[sym.top[0]].a) != "foo":
        fail("sym")
    print("ok")
