# mojo-ion

mojo-ion is an [Amazon Ion](https://amazon-ion.github.io/ion-docs/) serializer
written in [Mojo](https://www.modular.com/mojo). The runtime and the code
generator are Mojo. They do not wrap ion-c, ion-java, or any other C, C++, or
Rust Ion library.

<div class="grid cards" markdown="1">

-   __Why Ion__

    ---

    What an Ion value is, how text and binary differ, and which types keep
    more information than JSON.

    [:octicons-arrow-right-24: Read Why Ion](why-ion.md)

-   __Instructions__

    ---

    Install Mojo 1.1.0 with pixi, decode a datagram, generate Mojo from a
    schema, and run the tests.

    [:octicons-arrow-right-24: Open Instructions](instructions.md)

-   __Examples__

    ---

    Encode and decode a dynamic document and a generated struct.

    [:octicons-arrow-right-24: See Examples](examples.md)

-   __Techniques__

    ---

    How the document arena, symbol tables, and Ion 1.1 macros are laid out.

    [:octicons-arrow-right-24: Read Techniques](techniques.md)

-   __Test data__

    ---

    The vendored ion-tests corpus and the local schema files.

    [:octicons-arrow-right-24: Open Test data](test-data.md)

</div>
