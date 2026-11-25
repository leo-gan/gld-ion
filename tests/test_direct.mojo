from runtime.options import EncodeOptions
from runtime.symtab import Catalog
from wire.binary import decode_binary
from wire.direct import IonBin, IonCur
from wire.writer import encode_binary


def fail(msg: String) raises:
    print(msg)
    raise Error(msg)


def check_round(raw: List[Byte], sid_a: Int) raises:
    var cat = Catalog()
    var doc = decode_binary(Span(raw), cat)
    var again = encode_binary(doc, EncodeOptions(True, False, 10), cat)
    var back = decode_binary(Span(again), cat)
    _ = back
    var cur = IonCur(Span(raw))
    cur.open()
    var end = cur.enter_struct()
    if cur.field_sid() != sid_a:
        fail("sid")
    if cur.read_i64() != 1:
        fail("int")
    if cur.field_sid() != sid_a + 1:
        fail("sid b")
    if cur.read_string() != "hi":
        fail("str")
    var nest = cur.field_sid()
    _ = nest
    var lend = cur.enter_list()
    if cur.read_f64() != 1.5:
        fail("f64")
    if cur.read_bool() != True:
        fail("bool")
    if cur.read_i64() != -2:
        fail("neg")
    var long = cur.read_string()
    if long.byte_length() != 20 or long != "0123456789abcdefghij":
        fail("long")
    if cur.i != lend or cur.i != end:
        fail("end")


def main() raises:
    var bin = IonBin(capacity=128)
    var sa = bin.intern_lit("a")
    var sb = bin.intern_lit("b")
    var sc = bin.intern_lit("c")
    bin.begin()
    var st = bin.open_container()
    bin.field(sa)
    bin.write_i64(1)
    bin.field(sb)
    bin.write_str(String("hi"))
    bin.field(sc)
    var lst = bin.open_container()
    bin.write_f64(1.5)
    bin.write_bool(True)
    bin.write_i64(-2)
    bin.write_str(String("0123456789abcdefghij"))
    bin.close_container(lst, 11)
    bin.close_container(st, 13)
    var raw = bin^.take()
    check_round(raw^, sa)
    print("ok")
