from ion import Catalog, EncodeOptions, decode, encode


def main() raises:
    var cat = Catalog()
    var doc = decode(String("{a:1,b:\"hi\"}\n").as_bytes(), cat)
    var text = encode(doc, EncodeOptions(False, False, 10), cat)
    var binary = encode(doc, EncodeOptions(True, False, 11), cat)
    print("text bytes", len(text))
    print("ion 1.1 binary bytes", len(binary))
