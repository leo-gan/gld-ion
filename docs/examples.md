# Examples

The dynamic API and the generated API write the same Ion. Use the dynamic API
when the shape is not known ahead of time. Use a generated struct when a schema
already names the fields.

## Dynamic document

`examples/encode_value.mojo` decodes one struct and writes it twice.

```mojo
from ion import Catalog, EncodeOptions, decode, encode

fn main() raises:
    var cat = Catalog()
    var doc = decode(String("{a:1,b:\"hi\"}\n").as_bytes(), cat)
    var text = encode(doc, EncodeOptions(False, False, 10), cat)
    var binary = encode(doc, EncodeOptions(True, False, 11), cat)
    print("text bytes", len(text))
    print("ion 1.1 binary bytes", len(binary))
```

Run it from a checkout:

```bash
pixi run mojo run -I src examples/encode_value.mojo
```

Ion 1.0 text starts with `$ion_1_0`. Ion 1.1 binary starts with `E0 01 01 EA`
and stores the field name `a` as inline symbol text, so the stream has no
symbol table.

## Build a value without parsing

```mojo
from runtime.doc import IonDoc

fn main() raises:
    var doc = IonDoc()
    var st = doc.start_container(13)
    var field = doc.add_symbol_text("n")
    doc.add_child(st, doc.add_i64(150), doc.nodes[field].a)
    doc.add_top(st)
```

`13` is the struct kind. `add_i64` accepts any `Int64`. Wider integers go
through `add_int` and a `BigInt`. `add_decimal` keeps the coefficient and the
exponent, including a negative zero. `add_time` keeps precision and offset.

## Generated struct

`testdata/schema/message.json` describes a closed object. After `pixi run
generate`, `tests/generated/Message.mojo` has the fields below.

| Schema field | Mojo field | Required |
| --- | --- | --- |
| `id` | `Int64` | yes |
| `name` | `String` | yes |
| `ok` | `Bool` | no |
| `weight` | `Float64` | no |
| `tags` | `List[String]` | no |
| `when` | `String` holding Ion timestamp text | no |
| `payload` | `List[Byte]` | no |

```mojo
from runtime.options import EncodeOptions
from Message import Message

fn main() raises:
    var msg = Message()
    msg.id = Int64(7)
    msg.name = String("ada")
    msg.has_when = True
    msg.when = "2023T"
    var buf = List[Byte]()
    msg.encode_to(buf, EncodeOptions(True, False, 10))
    var back = Message.decode_from(buf)
```

Optional fields use a `has_` flag. A missing flag omits the field. A closed
schema raises `DecodeError.KIND_SCHEMA` when a required field is absent or an
unknown field is present.

`testdata/schema/point.ion` is Ion Schema. `label` is a symbol, so the
generated `String` holds Ion symbol text such as `foo`, not a quoted string.
`encode_to` with version `11` writes an Ion 1.1 binary struct.
