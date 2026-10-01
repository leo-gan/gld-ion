from runtime.eq import docs_eq
from runtime.options import EncodeOptions
from runtime.symtab import Catalog
from wire.binary import decode_binary
from wire.text import decode_text
from wire.writer import encode_binary, encode_text


def fail(msg: String) raises:
    print(msg)
    raise Error(msg)


def check(src: String) raises:
    var cat = Catalog()
    var doc = decode_text(src.as_bytes(), cat)
    var text = encode_text(doc, EncodeOptions(False, False, 10))
    var again = decode_text(text.as_bytes(), cat)
    if not docs_eq(doc, again):
        fail("round")


def main() raises:
    check(String("1\n"))
    check(String("{a:1, b:[true, \"hi\"]}\n"))
    check(String("null.int\n"))
    check(String("2007-02-23T12:14:33.079-08:00\n"))
    check(String("-0.00\n"))
    check(String("$ion_1_0\n$ion_symbol_table::{symbols:[\"foo\"]}\n$10\n"))
    var cat = Catalog()
    var doc = decode_text(String("{a:1, b:\"hi\"}\n").as_bytes(), cat)
    var bytes = encode_binary(doc, EncodeOptions(True, False, 10), cat)
    var back = decode_binary(Span(bytes), cat)
    if not docs_eq(doc, back):
        fail("bin")
    print("ok")
