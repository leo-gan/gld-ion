# mojo-ion

A from-scratch Amazon Ion implementation for [Mojo](https://www.modular.com/mojo).
The runtime and the code generator are written in Mojo. They do not wrap, link,
or vendor ion-c, ion-java, ion-rust, or any other C, C++, or Rust Ion library.

Python `amazon-ion` is a **test oracle** only. It is not required to encode or
decode at runtime.

This repository is a standalone library. It is not part of any other project.

Documentation: [Why Ion](https://leo-gan.github.io/gld-ion/why-ion/),
[Instructions](https://leo-gan.github.io/gld-ion/instructions/),
[Examples](https://leo-gan.github.io/gld-ion/examples/),
[Techniques](https://leo-gan.github.io/gld-ion/techniques/),
[Test data](https://leo-gan.github.io/gld-ion/test-data/).

## Install

Published package (linux-64) on [prefix.dev/leo-gan/leo-gan](https://prefix.dev/leo-gan/leo-gan):

```bash
pixi add --channel https://prefix.dev/leo-gan/leo-gan mojo-ion
```

That installs `ion.mojoc` (plus `wire`, `runtime`, and `schema`) and the
`gld-iongen-mojo` CLI. It needs `mojo-compiler` 1.1. After install,
`from ion import …` resolves with no extra `-I`.

From a git checkout (development):

```bash
git clone https://github.com/leo-gan/gld-ion.git
cd gld-ion
pixi install
pixi run test
```

Local precompile (no conda install):

```bash
pixi run precompile
```

`from ion import …` then resolves from `/tmp/mojo-ion-pkg`
(`mojo run -I /tmp/mojo-ion-pkg …`).

The recipe is `conda.recipe/recipe.yaml`. A GitHub Release on this repo builds
it and uploads it to the channel above.

## What it reads and writes

| Surface | Behavior |
| --- | --- |
| Ion 1.0 text and binary | Decode every legal value in the vendored ion-tests corpus. Encode compact text or length-prefixed binary. |
| Ion 1.1 draft | Little-endian values, inline symbols, delimited containers, directives, and template macros. |
| Numbers | Arbitrary-precision integers and decimals. Decimal scale is kept, so `1.0` and `1.00` stay distinct. |
| Timestamps | Instant, local offset, and precision from year through fractional seconds. |
| Schema | JSON Schema objects and Ion Schema `type` definitions. `gld-iongen-mojo` emits structs with `encoded_len`, `encode_to`, and `decode_from`. |

The encoder drops comments and whitespace. Two encodes of the same value match
when the options match. A catalog supplies shared symbol tables. Unknown
imported symbols stay unknown and compare by import name and import id.

## Layout

`src/ion` is the public package. `src/runtime` holds the document arena, big
integers, and symbol tables. `src/wire` holds the text parser, the Ion 1.0
binary parser, the Ion 1.1 reader and writer, and the encoders. `src/schema`
and `src/codegen` turn a schema into Mojo.

Requires **Mojo 1.1.0**.
