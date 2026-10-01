from runtime.doc import IonDoc
from runtime.intx import BigInt, big_from_be, big_from_digits, big_from_u64
from std.collections import List


def fail(msg: String) raises:
    print(msg)
    raise Error(msg)


def main() raises:
    var b = big_from_u64(UInt64(123456789), False)
    if b.to_dec() != "123456789":
        fail(b.to_dec())
    var neg = big_from_u64(UInt64(99), True)
    if neg.to_dec() != "-99":
        fail(neg.to_dec())
    var digits = List[Byte]()
    var s = String("100000000000000000000")
    var raw = s.as_bytes()
    var z = big_from_digits(raw, False)
    if z.to_dec() != "100000000000000000000":
        fail(z.to_dec())
    var be = List[Byte]()
    be.append(Byte(0x01))
    be.append(Byte(0x00))
    var w = big_from_be(be, False, 0)
    if w.to_dec() != "256":
        fail(w.to_dec())
    var doc = IonDoc()
    var n = doc.add_i64(Int64(-42))
    if doc.nodes[n].c != 1:
        fail("sign")
    _ = digits
    _ = BigInt()
    print("ok")
