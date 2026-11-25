"""Ion 1.0 binary cursor for structs, lists, bools, ints, float64, and strings.

Field names are user symbols in the local symbol table (sid 10 and up).
Each value is written into the caller's buffer. Container lengths are patched
in place, so a nested value is not copied through a second list.
"""

from std.collections import List, Span
from std.memory import unsafe_memcpy

from runtime.error import DecodeError


def _vu_len(v: Int) -> Int:
    var n = 1
    var x = v >> 7
    while x > 0:
        n += 1
        x = x >> 7
        if n > 5:
            return 5
    return n


struct IonBin(Movable):
    """Writes one Ion 1.0 binary value.

    Call `intern` for every field name, then `begin`, then the value.
    `begin` writes the version marker and the symbol table. Later `write_*`
    calls store the live bytes.
    """

    var buf: List[Byte]
    var pos: Int
    var syms: List[String]

    def __init__(out self, capacity: Int = 256):
        var cap = capacity
        if cap < 64:
            cap = 64
        self.buf = List[Byte](unsafe_uninit_length=cap)
        self.pos = 0
        self.syms = List[String]()

    def ensure(mut self, n: Int):
        var need = self.pos + n
        if need > len(self.buf):
            var cap = len(self.buf)
            while cap < need:
                cap = cap * 2
            self.buf.resize(unsafe_uninit_length=cap)

    def _u8(mut self, b: Int):
        self.ensure(1)
        self.buf[self.pos] = Byte(b & 255)
        self.pos += 1

    def _store_vu(mut self, at: Int, v: Int, n: Int):
        var i = n - 1
        while i >= 0:
            var b = (v >> (i * 7)) & 0x7F
            if i == 0:
                b = b | 0x80
            self.buf[at + (n - 1 - i)] = Byte(b)
            i -= 1

    def varuint(mut self, v: Int):
        var n = _vu_len(v)
        self.ensure(n)
        self._store_vu(self.pos, v, n)
        self.pos += n

    def write_span[origin: ImmOrigin](mut self, raw: Span[Byte, origin]):
        var n = len(raw)
        if n < 14:
            self._u8(0x80 | n)
        else:
            self._u8(0x8E)
            self.varuint(n)
        if n == 0:
            return
        self.ensure(n)
        unsafe_memcpy(
            dest=self.buf.unsafe_ptr().unsafe_offset(self.pos),
            src=raw.unsafe_ptr(),
            count=n,
        )
        self.pos += n

    def write_str(mut self, text: String):
        self.write_span(text.as_bytes())

    def intern(mut self, text: String) -> Int:
        var i = 0
        while i < len(self.syms):
            if self.syms[i] == text:
                return 10 + i
            i += 1
        self.syms.append(text)
        return 9 + len(self.syms)

    def intern_lit(mut self, text: StaticString) -> Int:
        return self.intern(String(text))

    def begin(mut self) raises DecodeError:
        """Version marker and the local symbol table. Names must already be interned."""
        self.pos = 0
        self._u8(0xE0)
        self._u8(0x01)
        self._u8(0x00)
        self._u8(0xEA)
        if len(self.syms) == 0:
            return
        var mark = self.open_container()
        self.varuint(1)
        self.varuint(3)
        var smark = self.open_container()
        self.varuint(7)
        var lmark = self.open_container()
        var i = 0
        while i < len(self.syms):
            var text = self.syms[i]
            self.write_str(text)
            i += 1
        self.close_container(lmark, 11)
        self.close_container(smark, 13)
        self.close_container(mark, 14)

    def open_container(mut self) -> Int:
        self.ensure(6)
        var mark = self.pos
        self.pos += 6
        return mark

    def close_container(mut self, mark: Int, tcode: Int) raises DecodeError:
        var body = mark + 6
        var ln = self.pos - body
        if ln < 14:
            self._shift_left(body, self.pos, 5)
            self.pos -= 5
            self.buf[mark] = Byte((tcode << 4) | ln)
            return
        var vl = _vu_len(ln)
        if vl > 5:
            raise DecodeError(DecodeError.KIND_RANGE, mark, ln)
        var slack = 5 - vl
        if slack > 0:
            self._shift_left(body, self.pos, slack)
            self.pos -= slack
        self.buf[mark] = Byte((tcode << 4) | 14)
        self._store_vu(mark + 1, ln, vl)

    def _shift_left(mut self, start: Int, end: Int, n: Int):
        # The reserved header is at most 5 bytes, so the move overlaps.
        # An 8-byte load finishes before the store, and the next load starts
        # at or after the bytes that store just wrote.
        if n <= 0 or start >= end:
            return
        var i = start
        var ptr = self.buf.unsafe_ptr()
        while i + 8 <= end:
            var w = ptr.unsafe_offset(i).unsafe_bitcast[UInt64]()[]
            ptr.unsafe_offset(i - n).unsafe_bitcast[UInt64]()[] = w
            i += 8
        while i < end:
            self.buf[i - n] = self.buf[i]
            i += 1

    def field(mut self, sid: Int):
        self.varuint(sid)

    def write_bool(mut self, v: Bool):
        if v:
            self._u8(0x11)
        else:
            self._u8(0x10)

    def write_i64(mut self, v: Int64):
        var neg = False
        var mag = UInt64(v)
        if v < 0:
            neg = True
            if v == Int64(-9223372036854775807) - Int64(1):
                mag = UInt64(1) << 63
            else:
                mag = UInt64(Int64(0) - v)
        var width = 0
        var probe = mag
        while probe > 0:
            width += 1
            probe = probe >> 8
        var t = 2
        if neg:
            t = 3
        self._u8((t << 4) | width)
        var s = width - 1
        while s >= 0:
            self._u8(Int((mag >> UInt64(s * 8)) & 255))
            s -= 1

    def write_f64(mut self, v: Float64):
        self.ensure(9)
        self.buf[self.pos] = Byte(0x48)
        var bits = UInt64(v.to_bits())
        var s = 7
        while s >= 0:
            self.buf[self.pos + 1 + (7 - s)] = Byte(Int((bits >> UInt64(s * 8)) & 255))
            s -= 1
        self.pos += 9

    def take(deinit self) -> List[Byte]:
        if self.pos < len(self.buf):
            self.buf.resize(unsafe_uninit_length=self.pos)
        return self.buf^


struct IonCur[origin: ImmOrigin](Movable):
    """Reads one value written by `IonBin`, including its symbol table."""

    var raw: Span[Byte, Self.origin]
    var i: Int
    var syms: List[String]

    def __init__(out self, raw: Span[Byte, Self.origin]):
        self.raw = raw
        self.i = 0
        self.syms = List[String]()

    def open(mut self) raises DecodeError:
        self._header()

    def _u8(mut self) raises DecodeError -> Int:
        if self.i >= len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var b = Int(self.raw.unsafe_ptr().unsafe_load(self.i))
        self.i += 1
        return b

    def _varuint(mut self) raises DecodeError -> Int:
        var v = 0
        var n = 0
        while n < 10:
            var b = self._u8()
            v = (v << 7) | (b & 0x7F)
            n += 1
            if (b & 0x80) != 0:
                return v
        raise DecodeError(DecodeError.KIND_RANGE, self.i)

    def _header(mut self) raises DecodeError:
        if len(self.raw) < 4:
            raise DecodeError(DecodeError.KIND_EOF, 0)
        if Int(self.raw[0]) != 0xE0 or Int(self.raw[1]) != 0x01 or Int(self.raw[2]) != 0x00 or Int(self.raw[3]) != 0xEA:
            raise DecodeError(DecodeError.KIND_VERSION, 0)
        self.i = 4
        if self.i >= len(self.raw):
            return
        var td = Int(self.raw.unsafe_ptr().unsafe_load(self.i))
        if (td >> 4) == 14:
            self._lst()

    def _enter(mut self, tcode: Int) raises DecodeError -> Int:
        var td = self._u8()
        if (td >> 4) != tcode:
            raise DecodeError(DecodeError.KIND_TYPE, self.i - 1, tcode)
        var ln = td & 0x0F
        if ln == 15:
            raise DecodeError(DecodeError.KIND_TYPE, self.i - 1, tcode)
        if ln == 14:
            ln = self._varuint()
        var end = self.i + ln
        if end > len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i, ln)
        return end

    def _lst(mut self) raises DecodeError:
        var end = self._enter(14)
        var ann_len = self._varuint()
        var ann_end = self.i + ann_len
        if ann_end > end:
            raise DecodeError(DecodeError.KIND_RANGE, self.i, ann_len)
        var sid = self._varuint()
        if sid != 3:
            raise DecodeError(DecodeError.KIND_SYMBOL, self.i, sid)
        self.i = ann_end
        var send = self._enter(13)
        var field = self._varuint()
        if field != 7:
            raise DecodeError(DecodeError.KIND_SYMBOL, self.i, field)
        var lend = self._enter(11)
        while self.i < lend:
            var text = self.read_string()
            self.syms.append(text^)
        if self.i != lend or self.i != send or self.i != end:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

    def enter_struct(mut self) raises DecodeError -> Int:
        return self._enter(13)

    def enter_list(mut self) raises DecodeError -> Int:
        return self._enter(11)

    def field_sid(mut self) raises DecodeError -> Int:
        return self._varuint()

    def read_bool(mut self) raises DecodeError -> Bool:
        var td = self._u8()
        if td == 0x10:
            return False
        if td == 0x11:
            return True
        raise DecodeError(DecodeError.KIND_TYPE, self.i - 1, 1)

    def read_i64(mut self) raises DecodeError -> Int64:
        var td = self._u8()
        var t = td >> 4
        var ln = td & 0x0F
        if ln == 14:
            ln = self._varuint()
        if t != 2 and t != 3:
            raise DecodeError(DecodeError.KIND_TYPE, self.i - 1, 2)
        if self.i + ln > len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i, ln)
        var mag = UInt64(0)
        var k = 0
        while k < ln:
            mag = (mag << 8) | UInt64(self._u8())
            k += 1
        if t == 3:
            if mag == (UInt64(1) << 63):
                return Int64(-9223372036854775807) - Int64(1)
            return Int64(0) - Int64(mag)
        return Int64(mag)

    def read_f64(mut self) raises DecodeError -> Float64:
        var td = self._u8()
        if td != 0x48:
            raise DecodeError(DecodeError.KIND_TYPE, self.i - 1, 4)
        var bits = UInt64(0)
        var k = 0
        while k < 8:
            bits = (bits << 8) | UInt64(self._u8())
            k += 1
        return Float64(from_bits=bits)

    def read_string(mut self) raises DecodeError -> String:
        var td = self._u8()
        if (td >> 4) != 8:
            raise DecodeError(DecodeError.KIND_TYPE, self.i - 1, 8)
        var ln = td & 0x0F
        if ln == 15:
            raise DecodeError(DecodeError.KIND_TYPE, self.i - 1, 8)
        if ln == 14:
            ln = self._varuint()
        if self.i + ln > len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i, ln)
        var tmp = List[Byte]()
        if ln > 0:
            tmp = List[Byte](unsafe_uninit_length=ln)
            unsafe_memcpy(
                dest=tmp.unsafe_ptr(),
                src=self.raw.unsafe_ptr().unsafe_offset(self.i),
                count=ln,
            )
        self.i += ln
        try:
            return String(from_utf8=Span(unsafe_ptr=tmp.unsafe_ptr(), length=len(tmp)))
        except _:
            raise DecodeError(DecodeError.KIND_UTF8, self.i - ln, ln)
