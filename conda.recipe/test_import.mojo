from ion import Catalog, DecodeError, decode


def main() raises:
    var cat = Catalog()
    var doc = decode(String("1\n").as_bytes(), cat)
    if len(doc.top) != 1:
        raise Error("import decode failed")
    print("ion import ok", DecodeError.KIND_EOF)
