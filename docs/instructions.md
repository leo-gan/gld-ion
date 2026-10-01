# Instructions

These steps assume a Linux x86-64 machine and Mojo 1.1.0. The package name on
prefix.dev is `mojo-ion`. The Mojo import is `ion`.

## Install from prefix.dev

```bash
pixi add --channel https://prefix.dev/leo-gan/leo-gan mojo-ion
```

The package depends on `mojo-compiler` 1.1. After it is installed, `from ion
import decode` works without an extra include path. The same install provides
`gld-iongen-mojo`.

## Build this repository

```bash
git clone https://github.com/leo-gan/gld-ion.git
cd gld-ion
pixi install
pixi run test
```

`pixi.toml` pins `mojo ==1.1.0` and uses the Modular MAX channel plus
conda-forge, linux-64 only. If `pixi install` returns 401 from
`conda.modular.com`, export `PREFIX_API_KEY` and retry. A local `.env` file is
the place for that token. It is gitignored. Do not commit it.

| Task | What it runs |
| --- | --- |
| `pixi run test` | Unit tests, then every file in the vendored ion-tests corpus. |
| `pixi run generate` | Writes `tests/generated` from `testdata/schema`. |
| `pixi run check-generated` | Regenerates into a temp directory and diffs. |
| `pixi run precompile` | Writes `/tmp/mojo-ion-pkg` and `gld-iongen-mojo`. |
| `pixi run microbench` | Prints nanoseconds per encode and decode of a 32-struct document. |

## Decode and encode

```mojo
from ion import Catalog, EncodeOptions, decode, encode

fn main() raises:
    var cat = Catalog()
    var doc = decode(String("{a:1}\n").as_bytes(), cat)
    var raw = encode(doc, EncodeOptions(True, False, 10), cat)
    print(len(raw))
```

`EncodeOptions` fields:

| Field | Meaning |
| --- | --- |
| `binary` | When true, `encode` writes binary Ion. Otherwise it writes UTF-8 text. |
| `pretty` | Indent text. Binary ignores it. |
| `version` | `10` for Ion 1.0, `11` for the Ion 1.1 draft. |
| `add_import(name, version)` | Shared table the Ion 1.0 binary writer imports. |

A leading `E0 01` version marker selects the binary decoder. Any other byte
string is text. The text decoder accepts UTF-8 and transcodes UTF-16 or UTF-32
when a wide encoding is obvious from the first bytes.

## Generate Mojo

A JSON Schema file:

```bash
gld-iongen-mojo --schema testdata/schema/message.json --out tests/generated
```

An Ion Schema file is Ion text:

```bash
gld-iongen-mojo --schema testdata/schema/point.ion --out tests/generated
```

The generator writes one `.mojo` file per struct. Compile generated code with
`-I src` so `runtime` and `wire` resolve, and with `-I` pointing at the output
directory so structs can import each other.

## Document the package

```bash
pip install -r requirements-docs.txt
mkdocs build --strict
```

The site is Material for MkDocs with an indigo primary color and a teal accent.
