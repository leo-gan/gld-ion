from std.collections import List

from runtime.doc import IonDoc, K_BLOB, K_CLOB, K_LIST, K_STRUCT
from runtime.error import DecodeError
from runtime.options import EncodeOptions
from runtime.symtab import Catalog
from wire.bind import (
    as_bool,
    as_bytes,
    as_f64,
    as_i64,
    as_string,
    decode_any,
    field_name,
    ion_text,
    parse_ion,
)
from wire.writer import encode_binary, encode_text


struct Point(Movable):
    var x: Int64
    var has_y: Bool
    var y: Int64
    var label: String

    def __init__(out self):
        self.x = Int64(0)
        self.has_y = False
        self.y = Int64(0)
        self.label = String()

    def encoded_len(self, options: EncodeOptions) raises -> Int:
        var buf = List[Byte]()
        self.encode_to(buf, options)
        return len(buf)

    def encode_to(self, mut buf: List[Byte], options: EncodeOptions) raises:
        var doc = self.to_doc()
        var cat = Catalog()
        if options.binary:
            var raw = encode_binary(doc, options, cat)
            var i = 0
            while i < len(raw):
                buf.append(raw[i])
                i += 1
            return
        var text = encode_text(doc, options)
        var b = text.as_bytes()
        var k = 0
        while k < len(b):
            buf.append(b[k])
            k += 1

    def to_doc(self) raises -> IonDoc:
        var doc = IonDoc()
        var st = self.write_into(doc)
        doc.add_top(st)
        return doc^

    def write_into(self, mut doc: IonDoc) raises -> Int:
        var st = doc.start_container(K_STRUCT)
        var sym_x = doc.add_symbol_text("x")
        var slot_x = doc.nodes[sym_x].a
        var val_x = doc.add_i64(self.x)
        doc.add_child(st, val_x, slot_x)
        if self.has_y:
            var sym_y = doc.add_symbol_text("y")
            var slot_y = doc.nodes[sym_y].a
            var val_y = doc.add_i64(self.y)
            doc.add_child(st, val_y, slot_y)
        var sym_label = doc.add_symbol_text("label")
        var slot_label = doc.nodes[sym_label].a
        var val_label = parse_ion(doc, self.label, 8)
        doc.add_child(st, val_label, slot_label)
        return st

    @staticmethod
    def decode_from(raw: List[Byte]) raises -> Point:
        var doc = decode_any(Span(raw))
        if len(doc.top) != 1:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return Point.from_doc(doc, doc.top[0])

    @staticmethod
    def from_doc(doc: IonDoc, id: Int) raises -> Point:
        if doc.nodes[id].kind != K_STRUCT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var out = Point()
        var got_x = False
        var got_label = False
        var i = 0
        while i < doc.nodes[id].nchild:
            var fname = field_name(doc, id, i)
            var child = doc.child_at(id, i)
            if fname == "x":
                out.x = as_i64(doc, child)
                got_x = True
            elif fname == "y":
                out.y = as_i64(doc, child)
                out.has_y = True
            elif fname == "label":
                out.label = ion_text(doc, child, 8)
                got_label = True
            else:
                raise DecodeError(DecodeError.KIND_SCHEMA, 0)
            i += 1
        if not got_x:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        if not got_label:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return out^
