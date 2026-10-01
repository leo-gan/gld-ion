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


struct Message(Movable):
    var id: Int64
    var name: String
    var has_ok: Bool
    var ok: Bool
    var has_weight: Bool
    var weight: Float64
    var has_note: Bool
    var note: String
    var has_tags: Bool
    var tags: List[String]
    var has_when: Bool
    var when: String
    var has_payload: Bool
    var payload: List[Byte]

    def __init__(out self):
        self.id = Int64(0)
        self.name = String()
        self.has_ok = False
        self.ok = False
        self.has_weight = False
        self.weight = Float64(0)
        self.has_note = False
        self.note = String()
        self.has_tags = False
        self.tags = List[String]()
        self.has_when = False
        self.when = String()
        self.has_payload = False
        self.payload = List[Byte]()

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
        var sym_id = doc.add_symbol_text("id")
        var slot_id = doc.nodes[sym_id].a
        var val_id = doc.add_i64(self.id)
        doc.add_child(st, val_id, slot_id)
        var sym_name = doc.add_symbol_text("name")
        var slot_name = doc.nodes[sym_name].a
        var val_name = doc.add_string(self.name)
        doc.add_child(st, val_name, slot_name)
        if self.has_ok:
            var sym_ok = doc.add_symbol_text("ok")
            var slot_ok = doc.nodes[sym_ok].a
            var val_ok = doc.add_bool(self.ok)
            doc.add_child(st, val_ok, slot_ok)
        if self.has_weight:
            var sym_weight = doc.add_symbol_text("weight")
            var slot_weight = doc.nodes[sym_weight].a
            var bits_val_weight = self.weight.to_bits()
            var val_weight = doc.add_float(8, UInt64(bits_val_weight))
            doc.add_child(st, val_weight, slot_weight)
        if self.has_note:
            var sym_note = doc.add_symbol_text("note")
            var slot_note = doc.nodes[sym_note].a
            var val_note = doc.add_string(self.note)
            doc.add_child(st, val_note, slot_note)
        if self.has_tags:
            var sym_tags = doc.add_symbol_text("tags")
            var slot_tags = doc.nodes[sym_tags].a
            var val_tags = doc.start_container(K_LIST)
            var j_val_tags = 0
            while j_val_tags < len(self.tags):
                var item_val_tags = doc.add_string(self.tags[j_val_tags])
                doc.add_child(val_tags, item_val_tags, -1)
                j_val_tags += 1
            doc.add_child(st, val_tags, slot_tags)
        if self.has_when:
            var sym_when = doc.add_symbol_text("when")
            var slot_when = doc.nodes[sym_when].a
            var val_when = parse_ion(doc, self.when, 6)
            doc.add_child(st, val_when, slot_when)
        if self.has_payload:
            var sym_payload = doc.add_symbol_text("payload")
            var slot_payload = doc.nodes[sym_payload].a
            var raw_val_payload = List[Byte]()
            var j_val_payload = 0
            while j_val_payload < len(self.payload):
                raw_val_payload.append(self.payload[j_val_payload])
                j_val_payload += 1
            var val_payload = doc.add_bytes(9, raw_val_payload^)
            doc.add_child(st, val_payload, slot_payload)
        return st

    @staticmethod
    def decode_from(raw: List[Byte]) raises -> Message:
        var doc = decode_any(Span(raw))
        if len(doc.top) != 1:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return Message.from_doc(doc, doc.top[0])

    @staticmethod
    def from_doc(doc: IonDoc, id: Int) raises -> Message:
        if doc.nodes[id].kind != K_STRUCT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var out = Message()
        var got_id = False
        var got_name = False
        var i = 0
        while i < doc.nodes[id].nchild:
            var fname = field_name(doc, id, i)
            var child = doc.child_at(id, i)
            if fname == "id":
                out.id = as_i64(doc, child)
                got_id = True
            elif fname == "name":
                out.name = as_string(doc, child)
                got_name = True
            elif fname == "ok":
                out.ok = as_bool(doc, child)
                out.has_ok = True
            elif fname == "weight":
                out.weight = as_f64(doc, child)
                out.has_weight = True
            elif fname == "note":
                out.note = as_string(doc, child)
                out.has_note = True
            elif fname == "tags":
                if doc.nodes[child].kind != K_LIST:
                    raise DecodeError(DecodeError.KIND_TYPE, 0)
                var item_out_tags = String()
                var j_item_out_tags = 0
                while j_item_out_tags < doc.nodes[child].nchild:
                    item_out_tags = as_string(doc, doc.child_at(child, j_item_out_tags))
                    out.tags.append(item_out_tags)
                    j_item_out_tags += 1
                out.has_tags = True
            elif fname == "when":
                out.when = ion_text(doc, child, 6)
                out.has_when = True
            elif fname == "payload":
                out.payload = as_bytes(doc, child, 9)
                out.has_payload = True
            else:
                raise DecodeError(DecodeError.KIND_SCHEMA, 0)
            i += 1
        if not got_id:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        if not got_name:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return out^
