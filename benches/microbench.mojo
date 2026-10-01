from std.time import perf_counter_ns

from runtime.doc import IonDoc, K_STRUCT
from runtime.options import EncodeOptions
from runtime.symtab import Catalog
from wire.binary import decode_binary
from wire.text import decode_text
from wire.writer import encode_binary, encode_text


def _sample() -> IonDoc:
    var doc = IonDoc()
    var i = 0
    while i < 32:
        var st = doc.start_container(K_STRUCT)
        var name = doc.add_symbol_text("id")
        doc.add_child(st, doc.add_i64(Int64(i)), doc.nodes[name].a)
        var label = doc.add_symbol_text("name")
        doc.add_child(st, doc.add_string(String("item")), doc.nodes[label].a)
        doc.add_top(st)
        i += 1
    return doc^


def main() raises:
    var doc = _sample()
    var cat = Catalog()
    var opt = EncodeOptions(True, False, 10)
    var text_opt = EncodeOptions(False, False, 10)
    var n = 200
    var i = 0
    while i < 20:
        _ = encode_binary(doc, opt, cat)
        _ = encode_text(doc, text_opt)
        i += 1
    var t0 = perf_counter_ns()
    i = 0
    while i < n:
        _ = encode_binary(doc, opt, cat)
        i += 1
    var bin_ns = Int(perf_counter_ns() - t0) // n
    t0 = perf_counter_ns()
    i = 0
    while i < n:
        _ = encode_text(doc, text_opt)
        i += 1
    var text_ns = Int(perf_counter_ns() - t0) // n
    var raw = encode_binary(doc, opt, cat)
    var text = encode_text(doc, text_opt)
    i = 0
    while i < 20:
        _ = decode_binary(Span(raw), cat)
        _ = decode_text(text.as_bytes(), cat)
        i += 1
    t0 = perf_counter_ns()
    i = 0
    while i < n:
        _ = decode_binary(Span(raw), cat)
        i += 1
    var dec_bin = Int(perf_counter_ns() - t0) // n
    t0 = perf_counter_ns()
    i = 0
    while i < n:
        _ = decode_text(text.as_bytes(), cat)
        i += 1
    var dec_text = Int(perf_counter_ns() - t0) // n
    print("binary_encode_ns", bin_ns)
    print("text_encode_ns", text_ns)
    print("binary_decode_ns", dec_bin)
    print("text_decode_ns", dec_text)
    print("binary_bytes", len(raw))
    print("text_bytes", text.byte_length())
