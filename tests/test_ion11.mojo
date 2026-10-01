from std.collections import List

from runtime.doc import (
    IonDoc,
    K_DECIMAL,
    K_INT,
    K_LIST,
    K_NULL,
    K_STRING,
    K_STRUCT,
    K_SYMBOL,
    K_TIMESTAMP,
    PREC_DAY,
    PREC_FRAC,
    PREC_MIN,
    PREC_MONTH,
    PREC_SEC,
    PREC_YEAR,
)
from runtime.eq import ion_eq
from runtime.error import DecodeError
from runtime.symtab import Catalog, LocalTab
from wire.binary import decode_binary
from wire.ion11 import Ion11


def fail(msg: String) raises:
    raise Error(msg)


def parse(raw: List[Byte]) raises DecodeError -> IonDoc:
    var doc = IonDoc()
    var tab = LocalTab()
    var cat = Catalog()
    var view = Span(raw)
    var r = Ion11(view)
    r.read_top(doc, tab, cat)
    return doc^


def b(*vals: Int) -> List[Byte]:
    var out = List[Byte]()
    for v in vals:
        out.append(Byte(v))
    return out^


def main() raises:
    var doc = parse(b(0xE0, 0x01, 0x01, 0xEA, 0x60))
    if len(doc.top) != 1 or doc.nodes[doc.top[0]].kind != K_INT:
        fail("int 0")
    var zero = IonDoc()
    var z = zero.add_i64(0)
    if not ion_eq(doc, doc.top[0], zero, z):
        fail("int 0 value")

    doc = parse(b(0xE0, 0x01, 0x01, 0xEA, 0x8F, 0x02))
    if doc.nodes[doc.top[0]].kind != K_NULL or doc.nodes[doc.top[0]].a != K_INT:
        fail("null.int")

    doc = parse(b(0xE0, 0x01, 0x01, 0xEA, 0xB6, 0x61, 0x01, 0x61, 0x02, 0x61, 0x03))
    if doc.nodes[doc.top[0]].kind != K_LIST or doc.nodes[doc.top[0]].nchild != 3:
        fail("list")

    doc = parse(b(0xE0, 0x01, 0x01, 0xEA, 0xF0, 0xEF))
    if doc.nodes[doc.top[0]].kind != K_LIST or doc.nodes[doc.top[0]].nchild != 0:
        fail("empty delimited list")

    doc = parse(
        b(
            0xE0,
            0x01,
            0x01,
            0xEA,
            0xE1,
            0x93,
            0x66,
            0x6F,
            0x6F,
            0x93,
            0x62,
            0x61,
            0x72,
            0xEF,
            0x52,
            0x03,
        )
    )
    if doc.nodes[doc.top[0]].kind != K_SYMBOL:
        fail("sid after set_symbols")
    var text = doc.sym_text(doc.nodes[doc.top[0]].a)
    if text != "foo":
        fail("symbol text " + text)

    doc = parse(b(0xE0, 0x01, 0x01, 0xEA, 0xA3, 0x62, 0x61, 0x72))
    if doc.sym_text(doc.nodes[doc.top[0]].a) != "bar":
        fail("inline symbol")

    doc = parse(b(0xE0, 0x01, 0x01, 0xEA, 0x6E))
    if doc.nodes[doc.top[0]].kind != 2 or doc.nodes[doc.top[0]].a != 1:
        fail("true")

    _ = Catalog()
    _ = K_STRING
    _check_time(b(0xE0, 0x01, 0x01, 0xEA, 0x80, 0x35), 2023, 1, 1, 0, 0, 0, PREC_YEAR, True, 0)
    _check_time(b(0xE0, 0x01, 0x01, 0xEA, 0x82, 0x35, 0x7D), 2023, 10, 15, 0, 0, 0, PREC_DAY, True, 0)
    _check_time(
        b(0xE0, 0x01, 0x01, 0xEA, 0x84, 0x35, 0x7D, 0xCB, 0x1A, 0x02),
        2023,
        10,
        15,
        11,
        22,
        33,
        PREC_SEC,
        False,
        0,
    )
    _check_time(
        b(0xE0, 0x01, 0x01, 0xEA, 0x89, 0x35, 0x7D, 0xCB, 0xEA, 0x85),
        2023,
        10,
        15,
        11,
        22,
        33,
        PREC_SEC,
        False,
        75,
    )
    _check_time(b(0xE0, 0x01, 0x01, 0xEA, 0xF7, 0x05, 0x9B, 0x07), 1947, 1, 1, 0, 0, 0, PREC_YEAR, True, 0)
    _check_time(b(0xE0, 0x01, 0x01, 0xEA, 0xF7, 0x07, 0x9B, 0x07, 0x03), 1947, 12, 1, 0, 0, 0, PREC_MONTH, True, 0)
    _check_time(b(0xE0, 0x01, 0x01, 0xEA, 0xF7, 0x07, 0x9B, 0x07, 0x5F), 1947, 12, 23, 0, 0, 0, PREC_DAY, True, 0)
    doc = parse(
        b(
            0xE0,
            0x01,
            0x01,
            0xEA,
            0xE3,
            0xF1,
            0xA5,
            0x70,
            0x6F,
            0x69,
            0x6E,
            0x74,
            0xF3,
            0xFD,
            0x78,
            0xE9,
            0xFD,
            0x79,
            0xEA,
            0x60,
            0xEF,
            0xEF,
            0xEF,
            0x00,
            0x61,
            0x02,
            0x61,
            0x03,
        )
    )
    if doc.nodes[doc.top[0]].kind != K_STRUCT or doc.nodes[doc.top[0]].nchild != 2:
        fail("macro point")
    if doc.nodes[doc.child_at(doc.top[0], 0)].kind != K_INT:
        fail("macro x")
    doc = parse(b(0xE0, 0x01, 0x01, 0xEA, 0x72, 0x07, 0x00))
    var dec = doc.nodes[doc.top[0]]
    if dec.kind != K_DECIMAL or dec.c != 1 or dec.d != 3:
        fail("neg zero decimal")
    var cat = Catalog()
    var via = decode_binary(Span(b(0xE0, 0x01, 0x01, 0xEA, 0x60)), cat)
    if len(via.top) != 1 or via.nodes[via.top[0]].kind != K_INT:
        fail("decode_binary 1.1")
    print("ok")


def _check_time(
    raw: List[Byte],
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int,
    second: Int,
    prec: Int,
    unknown: Bool,
    off: Int,
) raises:
    var doc = parse(raw)
    if doc.nodes[doc.top[0]].kind != K_TIMESTAMP:
        fail("timestamp kind")
    var t = doc.times[doc.nodes[doc.top[0]].a]
    if t.year != year or t.month != month or t.day != day:
        fail("timestamp date")
    if t.hour != hour or t.minute != minute or t.second != second:
        fail("timestamp time")
    if t.prec != prec or t.unknown != unknown or t.off != off:
        fail("timestamp prec")
    _ = PREC_FRAC
    _ = PREC_MIN
