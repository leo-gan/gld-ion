from std.collections import List

from runtime.doc import (
    IonDoc,
    IonTime,
    K_INT,
    K_LIST,
    K_STRUCT,
    PREC_DAY,
    PREC_MIN,
    PREC_SEC,
    PREC_YEAR,
)
from runtime.eq import ion_eq
from runtime.intx import big_from_u64
from runtime.options import EncodeOptions
from runtime.symtab import Catalog
from wire.binary import decode_binary
from wire.writer import encode_binary


def fail(msg: String) raises:
    raise Error(msg)


def hex_of(raw: List[Byte]) -> String:
    var out = String()
    var i = 0
    while i < len(raw):
        var n = Int(raw[i])
        var hi = n >> 4
        var lo = n & 15
        if hi < 10:
            out = out + chr(48 + hi)
        else:
            out = out + chr(87 + hi)
        if lo < 10:
            out = out + chr(48 + lo)
        else:
            out = out + chr(87 + lo)
        i += 1
    return out


def round_one(doc: IonDoc) raises:
    var opt = EncodeOptions(True, False, 11)
    var cat = Catalog()
    var raw = encode_binary(doc, opt, cat)
    var back = decode_binary(Span(raw), cat)
    if len(back.top) != len(doc.top):
        fail("count " + hex_of(raw))
    var i = 0
    while i < len(doc.top):
        if not ion_eq(doc, doc.top[i], back, back.top[i]):
            fail("eq " + hex_of(raw))
        i += 1


def main() raises:
    var doc = IonDoc()
    doc.add_top(doc.add_i64(0))
    doc.add_top(doc.add_i64(1))
    doc.add_top(doc.add_i64(-1))
    doc.add_top(doc.add_i64(200))
    doc.add_top(doc.add_bool(True))
    doc.add_top(doc.add_bool(False))
    doc.add_top(doc.add_null(K_INT))
    doc.add_top(doc.add_string("hi"))
    doc.add_top(doc.add_symbol_text("foo"))
    var lst = doc.start_container(K_LIST)
    doc.add_child(lst, doc.add_i64(1), -1)
    doc.add_child(lst, doc.add_i64(2), -1)
    doc.add_child(lst, doc.add_i64(3), -1)
    doc.add_top(lst)
    var st = doc.start_container(K_STRUCT)
    var name = doc.add_symbol_text("a")
    doc.add_child(st, doc.add_i64(7), doc.nodes[name].a)
    doc.add_top(st)
    var coef = big_from_u64(UInt64(127), False)
    doc.add_top(doc.add_decimal(coef^, False, -2))
    var z = big_from_u64(UInt64(0), False)
    doc.add_top(doc.add_decimal(z^, True, 3))
    var when = IonTime()
    when.year = 1947
    when.prec = PREC_YEAR
    when.unknown = True
    doc.add_top(doc.add_time(when))
    var day = IonTime()
    day.year = 1947
    day.month = 12
    day.day = 23
    day.prec = PREC_DAY
    day.unknown = True
    doc.add_top(doc.add_time(day))
    var sec = IonTime()
    sec.year = 1947
    sec.month = 12
    sec.day = 23
    sec.hour = 11
    sec.minute = 22
    sec.second = 33
    sec.prec = PREC_SEC
    sec.unknown = False
    sec.off = 75
    doc.add_top(doc.add_time(sec))
    round_one(doc)
    var one = IonDoc()
    var c7 = big_from_u64(UInt64(7), False)
    one.add_top(one.add_decimal(c7^, False, 0))
    var opt = EncodeOptions(True, False, 11)
    var cat = Catalog()
    var raw = encode_binary(one, opt, cat)
    var hex = hex_of(raw)
    if hex != "e00101ea720107":
        fail("7d0 " + hex)
    var y = IonDoc()
    var t = IonTime()
    t.year = 1947
    t.prec = PREC_YEAR
    t.unknown = True
    y.add_top(y.add_time(t))
    raw = encode_binary(y, opt, cat)
    hex = hex_of(raw)
    if hex != "e00101eaf7059b07":
        fail("1947T " + hex)
    _ = PREC_MIN
    print("ok")
