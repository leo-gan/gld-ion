from std.collections import List

from runtime.options import EncodeOptions
from Message import Message
from Point import Point


def fail(msg: String) raises:
    raise Error(msg)


def main() raises:
    var msg = Message()
    msg.id = Int64(7)
    msg.name = String("ada")
    msg.has_ok = True
    msg.ok = True
    msg.has_weight = True
    msg.weight = Float64(1.5)
    msg.has_note = True
    msg.note = String("hi")
    msg.has_tags = True
    msg.tags.append(String("a"))
    msg.tags.append(String("b"))
    msg.has_when = True
    msg.when = String("2023T")
    msg.has_payload = True
    msg.payload.append(Byte(1))
    msg.payload.append(Byte(2))
    var opt = EncodeOptions(True, False, 10)
    var buf = List[Byte]()
    msg.encode_to(buf, opt)
    if msg.encoded_len(opt) != len(buf):
        fail("encoded_len")
    var back = Message.decode_from(buf)
    if back.id != Int64(7) or back.name != "ada" or not back.ok:
        fail("scalars")
    if not back.has_weight or back.weight != Float64(1.5):
        fail("weight")
    if back.note != "hi" or len(back.tags) != 2 or back.tags[0] != "a":
        fail("text fields")
    if back.when != "2023T":
        fail("when " + back.when)
    if len(back.payload) != 2 or Int(back.payload[0]) != 1:
        fail("blob")
    var point = Point()
    point.x = Int64(3)
    point.label = String("foo")
    buf = List[Byte]()
    var opt11 = EncodeOptions(True, False, 11)
    point.encode_to(buf, opt11)
    var got = Point.decode_from(buf)
    if got.x != Int64(3) or got.has_y or got.label != "foo":
        fail("point " + got.label)
    print("ok")
