from std.collections import List

from runtime.doc import (
    K_BLOB,
    K_BOOL,
    K_CLOB,
    K_DECIMAL,
    K_FLOAT,
    K_INT,
    K_LIST,
    K_NULL,
    K_SEXP,
    K_STRING,
    K_STRUCT,
    K_SYMBOL,
    K_TIMESTAMP,
    IonDoc,
    PREC_DAY,
    PREC_FRAC,
    PREC_MIN,
    PREC_MONTH,
    PREC_SEC,
    PREC_YEAR,
)
from runtime.error import DecodeError
from runtime.intx import BigInt
from runtime.options import EncodeOptions
from runtime.symtab import Catalog
from runtime.utf8 import append_utf8
from wire.bin11 import encode_values11
from wire.time import shift_days


def _sys(text: String) -> Int:
    if text == "$ion":
        return 1
    if text == "$ion_1_0":
        return 2
    if text == "$ion_symbol_table":
        return 3
    if text == "name":
        return 4
    if text == "version":
        return 5
    if text == "imports":
        return 6
    if text == "symbols":
        return 7
    if text == "max_id":
        return 8
    if text == "$ion_shared_symbol_table":
        return 9
    return 0


def _ident_ok(text: String) -> Bool:
    var b = text.as_bytes()
    if len(b) == 0:
        return False
    var c0 = Int(b[0])
    if c0 >= 48 and c0 <= 57:
        return False
    if not ((c0 >= 65 and c0 <= 90) or (c0 >= 97 and c0 <= 122) or c0 == 95 or c0 == 36):
        return False
    var i = 1
    while i < len(b):
        var c = Int(b[i])
        var ok = (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95 or c == 36
        if not ok:
            return False
        i += 1
    if text == "null" or text == "true" or text == "false" or text == "nan":
        return False
    return True


def _pad(mut buf: List[Byte], n: Int, width: Int):
    var s = String(n)
    var b = s.as_bytes()
    var i = len(b)
    while i < width:
        buf.append(Byte(48))
        i += 1
    i = 0
    while i < len(b):
        buf.append(b[i])
        i += 1


def _limbs(doc: IonDoc, at: Int, n: Int) -> BigInt:
    var limbs = List[UInt32]()
    var i = 0
    while i < n:
        limbs.append(doc.limbs[at + i])
        i += 1
    return BigInt(False, limbs^)


def _varuint(mut buf: List[Byte], value: Int):
    var v = value
    if v < 0:
        v = 0
    var parts = List[Int]()
    if v == 0:
        buf.append(Byte(0x80))
        return
    var x = v
    while x > 0:
        parts.append(x & 0x7F)
        x = x >> 7
    var i = len(parts) - 1
    while i >= 0:
        var b = parts[i]
        if i == 0:
            b = b | 0x80
        buf.append(Byte(b))
        i -= 1


def _varint(mut buf: List[Byte], v: Int, neg0: Bool):
    var neg = v < 0 or neg0
    var mag = v
    if mag < 0:
        mag = 0 - mag
    if mag < 64:
        var b = 0x80 | mag
        if neg:
            b = b | 0x40
        buf.append(Byte(b))
        return
    var lows = List[Int]()
    while mag >= 64:
        lows.append(mag & 0x7F)
        mag = mag >> 7
    var first = mag
    if neg:
        first = first | 0x40
    buf.append(Byte(first))
    var i = len(lows) - 1
    while i >= 0:
        var b = lows[i]
        if i == 0:
            b = b | 0x80
        buf.append(Byte(b))
        i -= 1


def _td(mut buf: List[Byte], t: Int, body: List[Byte]):
    var n = len(body)
    if n < 14:
        buf.append(Byte((t << 4) | n))
    else:
        buf.append(Byte((t << 4) | 14))
        _varuint(buf, n)
    var i = 0
    while i < n:
        buf.append(body[i])
        i += 1


struct SymMap:
    var texts: List[String]
    var sids: List[Int]

    def __init__(out self):
        self.texts = List[String]()
        self.sids = List[Int]()

    def sid(mut self, text: String) -> Int:
        var sys = _sys(text)
        if sys != 0:
            return sys
        var i = 0
        while i < len(self.texts):
            if self.texts[i] == text:
                return self.sids[i]
            i += 1
        var id = 10 + len(self.texts)
        self.texts.append(text)
        self.sids.append(id)
        return id


def _gather(doc: IonDoc, id: Int, mut sm: SymMap):
    var n = doc.nodes[id]
    var i = 0
    while i < n.ann_n:
        var s = doc.syms[doc.anns[n.ann + i]]
        if s.text >= 0:
            _ = sm.sid(doc.texts[s.text])
        i += 1
    if n.kind == K_SYMBOL:
        var s = doc.syms[n.a]
        if s.text >= 0:
            _ = sm.sid(doc.texts[s.text])
    if n.kind == K_LIST or n.kind == K_SEXP or n.kind == K_STRUCT:
        i = 0
        while i < n.nchild:
            if n.kind == K_STRUCT:
                var f = doc.syms[doc.field_at(id, i)]
                if f.text >= 0:
                    _ = sm.sid(doc.texts[f.text])
            _gather(doc, doc.child_at(id, i), sm)
            i += 1


def _quote(mut buf: List[Byte], text: String):
    buf.append(Byte(39))
    var b = text.as_bytes()
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 39 or c == 92:
            buf.append(Byte(92))
            buf.append(Byte(c))
        elif c < 32:
            buf.append(Byte(92))
            buf.append(Byte(120))
            var hi = (c >> 4) & 15
            var lo = c & 15
            if hi < 10:
                buf.append(Byte(48 + hi))
            else:
                buf.append(Byte(87 + hi))
            if lo < 10:
                buf.append(Byte(48 + lo))
            else:
                buf.append(Byte(87 + lo))
        else:
            buf.append(Byte(c))
        i += 1
    buf.append(Byte(39))


def _sym_text(mut buf: List[Byte], text: String):
    if _ident_ok(text):
        var b = text.as_bytes()
        var i = 0
        while i < len(b):
            buf.append(b[i])
            i += 1
    else:
        _quote(buf, text)


def _str(mut buf: List[Byte], text: String):
    buf.append(Byte(34))
    var b = text.as_bytes()
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 34 or c == 92:
            buf.append(Byte(92))
            buf.append(Byte(c))
        elif c == 10:
            buf.append(Byte(92))
            buf.append(Byte(110))
        elif c < 32:
            buf.append(Byte(92))
            buf.append(Byte(120))
            var hi = (c >> 4) & 15
            var lo = c & 15
            if hi < 10:
                buf.append(Byte(48 + hi))
            else:
                buf.append(Byte(87 + hi))
            if lo < 10:
                buf.append(Byte(48 + lo))
            else:
                buf.append(Byte(87 + lo))
        else:
            buf.append(Byte(c))
        i += 1
    buf.append(Byte(34))


def _nl(mut buf: List[Byte], options: EncodeOptions, depth: Int):
    if not options.pretty:
        return
    buf.append(Byte(10))
    var i = 0
    while i < depth:
        buf.append(Byte(32))
        buf.append(Byte(32))
        i += 1


def _write_text(doc: IonDoc, id: Int, mut buf: List[Byte], options: EncodeOptions, depth: Int) raises DecodeError:
    var n = doc.nodes[id]
    var a = 0
    while a < n.ann_n:
        var s = doc.syms[doc.anns[n.ann + a]]
        if s.text < 0:
            buf.append(Byte(36))
            buf.append(Byte(48))
        else:
            _sym_text(buf, doc.texts[s.text])
        buf.append(Byte(58))
        buf.append(Byte(58))
        a += 1
    var k = n.kind
    if k == K_NULL:
        buf.append(Byte(110))
        buf.append(Byte(117))
        buf.append(Byte(108))
        buf.append(Byte(108))
        if n.a != 0:
            buf.append(Byte(46))
            var name = String("null")
            if n.a == K_BOOL:
                name = "bool"
            elif n.a == K_INT:
                name = "int"
            elif n.a == K_FLOAT:
                name = "float"
            elif n.a == K_DECIMAL:
                name = "decimal"
            elif n.a == K_TIMESTAMP:
                name = "timestamp"
            elif n.a == K_STRING:
                name = "string"
            elif n.a == K_SYMBOL:
                name = "symbol"
            elif n.a == K_BLOB:
                name = "blob"
            elif n.a == K_CLOB:
                name = "clob"
            elif n.a == K_LIST:
                name = "list"
            elif n.a == K_SEXP:
                name = "sexp"
            elif n.a == K_STRUCT:
                name = "struct"
            var nb = name.as_bytes()
            var i = 0
            while i < len(nb):
                buf.append(nb[i])
                i += 1
        return
    if k == K_BOOL:
        var word = String("false")
        if n.a != 0:
            word = "true"
        var b = word.as_bytes()
        var i = 0
        while i < len(b):
            buf.append(b[i])
            i += 1
        return
    if k == K_INT:
        var mag = _limbs(doc, n.a, n.b)
        if n.c != 0:
            mag.neg = True
        var t = mag.to_dec_bytes()
        var i = 0
        while i < len(t):
            buf.append(t[i])
            i += 1
        return
    if k == K_FLOAT:
        _float_text(doc, id, buf)
        return
    if k == K_DECIMAL:
        _dec_text(doc, id, buf)
        return
    if k == K_TIMESTAMP:
        _time_text(doc, id, buf)
        return
    if k == K_STRING:
        _str(buf, doc.texts[n.a])
        return
    if k == K_SYMBOL:
        var s = doc.syms[n.a]
        if s.text < 0:
            buf.append(Byte(36))
            buf.append(Byte(48))
        else:
            _sym_text(buf, doc.texts[s.text])
        return
    if k == K_BLOB or k == K_CLOB:
        _lob_text(doc, id, buf)
        return
    if k == K_LIST or k == K_SEXP:
        var open = 91
        var close = 93
        if k == K_SEXP:
            open = 40
            close = 41
        buf.append(Byte(open))
        var i = 0
        while i < n.nchild:
            if i > 0 and not options.pretty:
                buf.append(Byte(44))
            _nl(buf, options, depth + 1)
            _write_text(doc, doc.child_at(id, i), buf, options, depth + 1)
            i += 1
        if n.nchild > 0:
            _nl(buf, options, depth)
        buf.append(Byte(close))
        return
    if k == K_STRUCT:
        buf.append(Byte(123))
        var i = 0
        while i < n.nchild:
            if i > 0 and not options.pretty:
                buf.append(Byte(44))
            _nl(buf, options, depth + 1)
            var f = doc.syms[doc.field_at(id, i)]
            if f.text < 0:
                buf.append(Byte(36))
                buf.append(Byte(48))
            else:
                _sym_text(buf, doc.texts[f.text])
            buf.append(Byte(58))
            _write_text(doc, doc.child_at(id, i), buf, options, depth + 1)
            i += 1
        if n.nchild > 0:
            _nl(buf, options, depth)
        buf.append(Byte(125))
        return
    raise DecodeError(DecodeError.KIND_TYPE, 0)


def _float_text(doc: IonDoc, id: Int, mut buf: List[Byte]):
    var n = doc.nodes[id]
    var bits = doc.floats[n.b]
    if n.a == 0:
        buf.append(Byte(48))
        buf.append(Byte(101))
        buf.append(Byte(48))
        return
    var f = Float64(0)
    if n.a == 4:
        f = Float64(Float32(from_bits=UInt32(bits)))
    elif n.a == 2:
        f = Float64(0)
    else:
        f = Float64(from_bits=bits)
    if f != f:
        buf.append(Byte(110))
        buf.append(Byte(97))
        buf.append(Byte(110))
        return
    var sign = (bits & (UInt64(1) << UInt64(63))) != UInt64(0)
    if n.a == 4:
        sign = (UInt32(bits) & UInt32(0x80000000)) != UInt32(0)
    if f == Float64(0) and sign:
        buf.append(Byte(45))
        buf.append(Byte(48))
        buf.append(Byte(101))
        buf.append(Byte(48))
        return
    var exp_all = False
    var raw = String(f)
    var b = raw.as_bytes()
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 101 or c == 69:
            exp_all = True
        buf.append(Byte(c))
        i += 1
    if not exp_all:
        buf.append(Byte(101))
        buf.append(Byte(48))


def _dec_text(doc: IonDoc, id: Int, mut buf: List[Byte]):
    var n = doc.nodes[id]
    var mag = _limbs(doc, n.a, n.b)
    var digits = mag.to_dec_bytes()
    if n.c != 0:
        buf.append(Byte(45))
    if n.d >= 0:
        var i = 0
        while i < len(digits):
            buf.append(digits[i])
            i += 1
        buf.append(Byte(100))
        var e = String(n.d)
        var eb = e.as_bytes()
        i = 0
        while i < len(eb):
            buf.append(eb[i])
            i += 1
        return
    var frac = 0 - n.d
    if len(digits) == 1 and Int(digits[0]) == 48:
        buf.append(Byte(48))
        buf.append(Byte(46))
        var z = 0
        while z < frac:
            buf.append(Byte(48))
            z += 1
        return
    if frac >= len(digits):
        buf.append(Byte(48))
        buf.append(Byte(46))
        var z = 0
        while z < frac - len(digits):
            buf.append(Byte(48))
            z += 1
        var i = 0
        while i < len(digits):
            buf.append(digits[i])
            i += 1
        return
    var cut = len(digits) - frac
    var i = 0
    while i < cut:
        buf.append(digits[i])
        i += 1
    buf.append(Byte(46))
    while i < len(digits):
        buf.append(digits[i])
        i += 1


def _time_text(doc: IonDoc, id: Int, mut buf: List[Byte]) raises DecodeError:
    var t = doc.times[doc.nodes[id].a]
    _pad(buf, t.year, 4)
    if t.prec == PREC_YEAR:
        buf.append(Byte(84))
        return
    buf.append(Byte(45))
    _pad(buf, t.month, 2)
    if t.prec == PREC_MONTH:
        buf.append(Byte(84))
        return
    buf.append(Byte(45))
    _pad(buf, t.day, 2)
    if t.prec == PREC_DAY:
        return
    buf.append(Byte(84))
    _pad(buf, t.hour, 2)
    buf.append(Byte(58))
    _pad(buf, t.minute, 2)
    if t.prec >= PREC_SEC:
        buf.append(Byte(58))
        _pad(buf, t.second, 2)
    if t.prec == PREC_FRAC:
        buf.append(Byte(46))
        var mag = _limbs(doc, t.frac_at, t.frac_len)
        var digits = mag.to_dec_bytes()
        var need = 0 - t.frac_exp
        var z = len(digits)
        while z < need:
            buf.append(Byte(48))
            z += 1
        var i = 0
        while i < len(digits):
            buf.append(digits[i])
            i += 1
    if t.unknown:
        buf.append(Byte(45))
        buf.append(Byte(48))
        buf.append(Byte(48))
        buf.append(Byte(58))
        buf.append(Byte(48))
        buf.append(Byte(48))
        return
    if t.off == 0:
        buf.append(Byte(90))
        return
    var off = t.off
    if off < 0:
        buf.append(Byte(45))
        off = 0 - off
    else:
        buf.append(Byte(43))
    _pad(buf, off // 60, 2)
    buf.append(Byte(58))
    _pad(buf, off % 60, 2)


def _lob_text(doc: IonDoc, id: Int, mut buf: List[Byte]):
    var n = doc.nodes[id]
    buf.append(Byte(123))
    buf.append(Byte(123))
    if n.kind == K_CLOB:
        buf.append(Byte(34))
        var i = 0
        var start = doc.blob_at[n.a]
        while i < doc.blob_len[n.a]:
            var c = Int(doc.blob_bytes[start + i])
            if c == 34 or c == 92:
                buf.append(Byte(92))
                buf.append(Byte(c))
            elif c >= 32 and c < 127:
                buf.append(Byte(c))
            else:
                buf.append(Byte(92))
                buf.append(Byte(120))
                var hi = (c >> 4) & 15
                var lo = c & 15
                if hi < 10:
                    buf.append(Byte(48 + hi))
                else:
                    buf.append(Byte(87 + hi))
                if lo < 10:
                    buf.append(Byte(48 + lo))
                else:
                    buf.append(Byte(87 + lo))
            i += 1
        buf.append(Byte(34))
    else:
        var i = 0
        var alpha = String("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
        var ab = alpha.as_bytes()
        var start = doc.blob_at[n.a]
        var length = doc.blob_len[n.a]
        while i < length:
            var b0 = Int(doc.blob_bytes[start + i])
            var b1 = 0
            var b2 = 0
            var have = 1
            if i + 1 < length:
                b1 = Int(doc.blob_bytes[start + i + 1])
                have = 2
            if i + 2 < length:
                b2 = Int(doc.blob_bytes[start + i + 2])
                have = 3
            var v = (b0 << 16) | (b1 << 8) | b2
            buf.append(ab[Int((v >> 18) & 63)])
            buf.append(ab[Int((v >> 12) & 63)])
            if have > 1:
                buf.append(ab[Int((v >> 6) & 63)])
            else:
                buf.append(Byte(61))
            if have > 2:
                buf.append(ab[Int(v & 63)])
            else:
                buf.append(Byte(61))
            i += 3
    buf.append(Byte(125))
    buf.append(Byte(125))
    _ = append_utf8


def encode_text(doc: IonDoc, options: EncodeOptions) raises DecodeError -> String:
    var buf = List[Byte]()
    if options.version == 11:
        var ivm = String("$ion_1_1")
        var b = ivm.as_bytes()
        var i = 0
        while i < len(b):
            buf.append(b[i])
            i += 1
    else:
        var ivm = String("$ion_1_0")
        var b = ivm.as_bytes()
        var i = 0
        while i < len(b):
            buf.append(b[i])
            i += 1
    var t = 0
    while t < len(doc.top):
        buf.append(Byte(10))
        _write_text(doc, doc.top[t], buf, options, 0)
        t += 1
    buf.append(Byte(10))
    return String(unsafe_from_utf8=buf)


def _be_mag(mag: BigInt) -> List[Byte]:
    return mag.to_be_bytes()


def _bin_value(doc: IonDoc, id: Int, mut sm: SymMap, mut buf: List[Byte]) raises DecodeError:
    var body = List[Byte]()
    var n = doc.nodes[id]
    var ann_body = List[Byte]()
    if n.ann_n > 0:
        var annots = List[Byte]()
        var a = 0
        while a < n.ann_n:
            var s = doc.syms[doc.anns[n.ann + a]]
            var sid = 0
            if s.text >= 0:
                sid = sm.sid(doc.texts[s.text])
            _varuint(annots, sid)
            a += 1
        _varuint(ann_body, len(annots))
        var i = 0
        while i < len(annots):
            ann_body.append(annots[i])
            i += 1
    var k = n.kind
    if k == K_NULL and n.a == 0:
        body.append(Byte(0x0F))
    elif k == K_NULL:
        var code = 0
        if n.a == K_BOOL:
            code = 0x1F
        elif n.a == K_INT:
            code = 0x2F
        elif n.a == K_FLOAT:
            code = 0x4F
        elif n.a == K_DECIMAL:
            code = 0x5F
        elif n.a == K_TIMESTAMP:
            code = 0x6F
        elif n.a == K_SYMBOL:
            code = 0x7F
        elif n.a == K_STRING:
            code = 0x8F
        elif n.a == K_CLOB:
            code = 0x9F
        elif n.a == K_BLOB:
            code = 0xAF
        elif n.a == K_LIST:
            code = 0xBF
        elif n.a == K_SEXP:
            code = 0xCF
        elif n.a == K_STRUCT:
            code = 0xDF
        body.append(Byte(code))
    elif k == K_BOOL:
        if n.a == 0:
            body.append(Byte(0x10))
        else:
            body.append(Byte(0x11))
    elif k == K_INT:
        var mag = _limbs(doc, n.a, n.b)
        var raw = _be_mag(mag)
        var t = 2
        if n.c != 0:
            t = 3
        _td(body, t, raw)
    elif k == K_FLOAT:
        if n.a == 0:
            body.append(Byte(0x40))
        else:
            var bits = doc.floats[n.b]
            var width = n.a
            var tmp = List[Byte]()
            var s = width - 1
            while s >= 0:
                tmp.append(Byte(Int((bits >> UInt64(s * 8)) & UInt64(255))))
                s -= 1
            _td(body, 4, tmp)
    elif k == K_DECIMAL:
        var tmp = List[Byte]()
        _varint(tmp, n.d, False)
        var mag = _limbs(doc, n.a, n.b)
        if n.c != 0 or n.b > 0:
            var be = _be_mag(mag)
            if n.c != 0:
                if len(be) == 0:
                    be.append(Byte(0x80))
                else:
                    be[0] = Byte(Int(be[0]) | 0x80)
            var i = 0
            while i < len(be):
                tmp.append(be[i])
                i += 1
        _td(body, 5, tmp)
    elif k == K_STRING or k == K_BLOB or k == K_CLOB:
        var tmp = List[Byte]()
        if k == K_STRING:
            var b = doc.texts[n.a].as_bytes()
            var i = 0
            while i < len(b):
                tmp.append(b[i])
                i += 1
            _td(body, 8, tmp)
        else:
            var i = 0
            var start = doc.blob_at[n.a]
            while i < doc.blob_len[n.a]:
                tmp.append(doc.blob_bytes[start + i])
                i += 1
            var tcode = 10
            if k == K_CLOB:
                tcode = 9
            _td(body, tcode, tmp)
    elif k == K_SYMBOL:
        var sid = 0
        var s = doc.syms[n.a]
        if s.text >= 0:
            sid = sm.sid(doc.texts[s.text])
        if sid == 0:
            body.append(Byte(0x70))
        else:
            var raw = BigInt()
            var tmp = List[Byte]()
            var x = sid
            if x == 0:
                tmp.append(Byte(0))
            while x > 0:
                tmp.append(Byte(x & 255))
                x = x >> 8
            var be = List[Byte]()
            var i = len(tmp) - 1
            while i >= 0:
                be.append(tmp[i])
                i -= 1
            _td(body, 7, be)
            _ = raw
    elif k == K_TIMESTAMP:
        _bin_time(doc, id, body)
    elif k == K_LIST or k == K_SEXP or k == K_STRUCT:
        var tmp = List[Byte]()
        var i = 0
        while i < n.nchild:
            if k == K_STRUCT:
                var f = doc.syms[doc.field_at(id, i)]
                var sid = 0
                if f.text >= 0:
                    sid = sm.sid(doc.texts[f.text])
                _varuint(tmp, sid)
            _bin_value(doc, doc.child_at(id, i), sm, tmp)
            i += 1
        var tcode = 11
        if k == K_SEXP:
            tcode = 12
        if k == K_STRUCT:
            tcode = 13
        _td(body, tcode, tmp)
    else:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    if n.ann_n > 0:
        var wrapped = List[Byte]()
        var i = 0
        while i < len(ann_body):
            wrapped.append(ann_body[i])
            i += 1
        i = 0
        while i < len(body):
            wrapped.append(body[i])
            i += 1
        _td(buf, 14, wrapped)
    else:
        var i = 0
        while i < len(body):
            buf.append(body[i])
            i += 1


def _bin_time(doc: IonDoc, id: Int, mut buf: List[Byte]) raises DecodeError:
    var t = doc.times[doc.nodes[id].a]
    var tmp = List[Byte]()
    if t.prec < PREC_MIN or t.unknown:
        _varint(tmp, 0, True)
    else:
        _varint(tmp, t.off, False)
    var year = t.year
    var month = t.month
    var day = t.day
    var hour = t.hour
    var minute = t.minute
    if t.prec >= PREC_MIN and not t.unknown and t.off != 0:
        var total = hour * 60 + minute - t.off
        var days = 0
        while total < 0:
            total += 1440
            days -= 1
        while total >= 1440:
            total -= 1440
            days += 1
        hour = total // 60
        minute = total % 60
        if days != 0:
            var when = t
            when.hour = hour
            when.minute = minute
            shift_days(when, days)
            year = when.year
            month = when.month
            day = when.day
    _varuint(tmp, year)
    if t.prec >= PREC_MONTH:
        _varuint(tmp, month)
    if t.prec >= PREC_DAY:
        _varuint(tmp, day)
    if t.prec >= PREC_MIN:
        _varuint(tmp, hour)
        _varuint(tmp, minute)
    if t.prec >= PREC_SEC:
        _varuint(tmp, t.second)
    if t.prec == PREC_FRAC:
        _varint(tmp, t.frac_exp, False)
        var mag = _limbs(doc, t.frac_at, t.frac_len)
        var be = _be_mag(mag)
        var i = 0
        while i < len(be):
            tmp.append(be[i])
            i += 1
    _td(buf, 6, tmp)


def _write_lst(sm: SymMap, options: EncodeOptions, cat: Catalog, mut buf: List[Byte]) raises DecodeError:
    if len(sm.texts) == 0 and len(options.import_names) == 0:
        return
    var fields = List[Byte]()
    if len(options.import_names) > 0:
        _varuint(fields, 6)
        var items = List[Byte]()
        var i = 0
        while i < len(options.import_names):
            var item = List[Byte]()
            _varuint(item, 4)
            var nb = options.import_names[i].as_bytes()
            var raw = List[Byte]()
            var k = 0
            while k < len(nb):
                raw.append(nb[k])
                k += 1
            _td(item, 8, raw)
            _varuint(item, 5)
            var ver = BigInt()
            var vv = options.import_versions[i]
            var vb = List[Byte]()
            var x = vv
            if x == 0:
                vb.append(Byte(0))
            while x > 0:
                vb.append(Byte(x & 255))
                x = x >> 8
            var be = List[Byte]()
            k = len(vb) - 1
            while k >= 0:
                be.append(vb[k])
                k -= 1
            _td(item, 2, be)
            var max_id = 0
            var idx = cat.exact(options.import_names[i], options.import_versions[i])
            if idx >= 0:
                max_id = len(cat.tables[idx].texts)
            _varuint(item, 8)
            vb = List[Byte]()
            x = max_id
            if x == 0:
                vb.append(Byte(0))
            while x > 0:
                vb.append(Byte(x & 255))
                x = x >> 8
            be = List[Byte]()
            k = len(vb) - 1
            while k >= 0:
                be.append(vb[k])
                k -= 1
            _td(item, 2, be)
            _td(items, 13, item)
            _ = ver
            i += 1
        _td(fields, 11, items)
    if len(sm.texts) > 0:
        _varuint(fields, 7)
        var items = List[Byte]()
        var i = 0
        while i < len(sm.texts):
            var raw = List[Byte]()
            var b = sm.texts[i].as_bytes()
            var k = 0
            while k < len(b):
                raw.append(b[k])
                k += 1
            _td(items, 8, raw)
            i += 1
        _td(fields, 11, items)
    var structed = List[Byte]()
    _td(structed, 13, fields)
    var ann = List[Byte]()
    _varuint(ann, 1)
    _varuint(ann, 3)
    var i = 0
    while i < len(structed):
        ann.append(structed[i])
        i += 1
    _td(buf, 14, ann)


def encode_binary(doc: IonDoc, options: EncodeOptions, cat: Catalog) raises DecodeError -> List[Byte]:
    var sm = SymMap()
    var t = 0
    while t < len(doc.top):
        _gather(doc, doc.top[t], sm)
        t += 1
    var buf = List[Byte]()
    buf.append(Byte(0xE0))
    buf.append(Byte(0x01))
    if options.version == 11:
        buf.append(Byte(0x01))
    else:
        buf.append(Byte(0x00))
    buf.append(Byte(0xEA))
    if options.version == 11:
        encode_values11(doc, buf)
        return buf^
    _write_lst(sm, options, cat, buf)
    t = 0
    while t < len(doc.top):
        _bin_value(doc, doc.top[t], sm, buf)
        t += 1
    return buf^


def format_value(doc: IonDoc, id: Int) raises DecodeError -> String:
    """Text of one value, without an Ion version marker."""
    var buf = List[Byte]()
    var options = EncodeOptions()
    _write_text(doc, id, buf, options, 0)
    return String(unsafe_from_utf8=buf^)
