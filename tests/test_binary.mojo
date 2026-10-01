from runtime.symtab import Catalog
from std.collections import List
from wire.binary import decode_binary


def fail(msg: String) raises:
    print(msg)
    raise Error(msg)


def main() raises:
    var raw = List[Byte]()
    raw.append(Byte(0xE0))
    raw.append(Byte(0x01))
    raw.append(Byte(0x00))
    raw.append(Byte(0xEA))
    raw.append(Byte(0x20))
    raw.append(Byte(0x11))
    raw.append(Byte(0x0F))
    var cat = Catalog()
    var doc = decode_binary(Span(raw), cat)
    if len(doc.top) != 3:
        fail("count")
    if doc.nodes[doc.top[0]].kind != 3:
        fail("int")
    if doc.nodes[doc.top[1]].a != 1:
        fail("bool")
    if doc.nodes[doc.top[2]].kind != 1:
        fail("null")
    print("ok")
