from std.sys import argv

from runtime.doc import K_INT, K_LIST, K_NULL, K_SEXP, K_STRING, K_STRUCT, IonDoc
from runtime.eq import docs_eq, ion_eq
from runtime.error import DecodeError
from runtime.symtab import Catalog, SharedTable
from std.collections import List
from wire.binary import decode_binary
from wire.text import decode_text


def fail(msg: String) raises:
    raise Error(msg)


def _ann0(doc: IonDoc, id: Int) -> String:
    var n = doc.nodes[id]
    if n.ann_n == 0:
        return String()
    return doc.sym_text(doc.anns[n.ann])


def _field(doc: IonDoc, id: Int, name: String) -> Int:
    var i = 0
    while i < doc.nodes[id].nchild:
        var sym = doc.field_at(id, i)
        var s = doc.syms[sym]
        if s.text >= 0 and doc.texts[s.text] == name:
            return doc.child_at(id, i)
        i += 1
    return -1


def _as_int(doc: IonDoc, id: Int) -> Int:
    var n = doc.nodes[id]
    if n.kind != K_INT or n.b > 2 or n.c != 0:
        return 1
    var mag = 0
    if n.b > 0:
        mag = Int(doc.limbs[n.a])
    if n.b > 1:
        mag = mag + Int(doc.limbs[n.a + 1]) * 4294967296
    return mag


def load_catalog(doc: IonDoc) -> Catalog:
    var cat = Catalog()
    var i = 0
    while i < len(doc.top):
        var id = doc.top[i]
        if _ann0(doc, id) == "$ion_shared_symbol_table" and doc.nodes[id].kind == K_STRUCT:
            var name_id = _field(doc, id, "name")
            if name_id >= 0 and doc.nodes[name_id].kind == K_STRING:
                var version = 1
                var ver = _field(doc, id, "version")
                if ver >= 0 and doc.nodes[ver].kind == K_INT:
                    version = _as_int(doc, ver)
                var table = SharedTable(doc.text_at(name_id), version)
                var syms = _field(doc, id, "symbols")
                if syms >= 0 and doc.nodes[syms].kind == K_LIST:
                    var k = 0
                    while k < doc.nodes[syms].nchild:
                        var el = doc.child_at(syms, k)
                        if doc.nodes[el].kind == K_STRING:
                            table.add(doc.text_at(el), False)
                        else:
                            table.add(String(), True)
                        k += 1
                cat.add(table^)
        i += 1
    return cat^


def read_bytes(path: String) raises -> List[Byte]:
    var f = open(path, "r")
    var data = f.read_bytes()
    f.close()
    return data^


def parse_path(path: String, cat: Catalog) raises -> IonDoc:
    var data = read_bytes(path)
    if path.endswith(".10n"):
        return decode_binary(Span(data), cat)
    return decode_text(Span(data), cat)


def parse_bytes(data: List[Byte], binary: Bool, cat: Catalog) raises DecodeError -> IonDoc:
    if binary:
        return decode_binary(Span(data), cat)
    return decode_text(Span(data), cat)


def _embedded(doc: IonDoc, id: Int) -> Bool:
    var n = doc.nodes[id]
    if n.ann_n == 0:
        return False
    return doc.sym_text(doc.anns[n.ann]) == "embedded_documents"


def _seq_ok(doc: IonDoc, id: Int, want_eq: Bool, cat: Catalog) raises -> Bool:
    var n = doc.nodes[id]
    if n.kind != K_LIST and n.kind != K_SEXP:
        return False
    if n.nchild < 2:
        return False
    if _embedded(doc, id):
        var first = IonDoc()
        var i = 0
        while i < n.nchild:
            var el = doc.child_at(id, i)
            if doc.nodes[el].kind != K_STRING:
                return False
            var text = doc.text_at(el)
            var got = decode_text(text.as_bytes(), cat)
            if i == 0:
                first = got^
            else:
                var eq = docs_eq(first, got)
                if want_eq and not eq:
                    return False
                if not want_eq and eq:
                    return False
            i += 1
        return True
    var i = 1
    while i < n.nchild:
        var eq = ion_eq(doc, doc.child_at(id, 0), doc, doc.child_at(id, i))
        if want_eq and not eq:
            return False
        if not want_eq and eq:
            return False
        i += 1
    if not want_eq:
        var a = 0
        while a < n.nchild:
            var b = a + 1
            while b < n.nchild:
                if ion_eq(doc, doc.child_at(id, a), doc, doc.child_at(id, b)):
                    return False
                b += 1
            a += 1
    return True


def _has(path: String, needle: String) -> Bool:
    return path.find(needle) >= 0


def main() raises:
    var args = argv()
    if len(args) < 2:
        fail("path")
    var path = args[1]
    var cat_path = String("testdata/ion-tests/catalog/catalog.ion")
    if len(args) >= 3:
        cat_path = args[2]
    var cat_doc = decode_text(read_bytes(cat_path), Catalog())
    var cat = load_catalog(cat_doc)
    var expect_bad = _has(path, "/bad/")
    var equiv = _has(path, "/equivs/")
    var noneq = _has(path, "/non-equivs/")
    var ok = False
    try:
        var doc = parse_path(path, cat)
        if expect_bad:
            ok = False
        elif equiv or noneq:
            ok = len(doc.top) > 0
            var k = 0
            while k < len(doc.top) and ok:
                ok = _seq_ok(doc, doc.top[k], equiv, cat)
                k += 1
        else:
            ok = True
    except _:
        ok = expect_bad
    if ok:
        print("OK")
    else:
        print("FAIL")
        fail(path)
