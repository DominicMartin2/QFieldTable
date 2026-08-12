.pragma library
function toUint8Array(data) {
    if (data === null || data === undefined)
        throw new Error("Données binaires absentes")

    if (typeof Uint8Array !== "undefined" && data instanceof Uint8Array)
        return data
    if (typeof ArrayBuffer !== "undefined" && data instanceof ArrayBuffer)
        return new Uint8Array(data)

    try {
        if (data.buffer instanceof ArrayBuffer) {
            var offset = data.byteOffset || 0
            var length = data.byteLength !== undefined ? data.byteLength : undefined
            return length !== undefined
                    ? new Uint8Array(data.buffer, offset, length)
                    : new Uint8Array(data.buffer)
        }
    } catch (e1) {}

    try {
        var converted = new Uint8Array(data)
        if (converted.length > 0) return converted
    } catch (e2) {}

    try {
        var n = Number(data.length)
        if (!isNaN(n) && n >= 0) {
            var result = new Uint8Array(n)
            for (var i = 0; i < n; ++i) {
                var value = data[i]
                if (value === undefined && typeof data.at === "function")
                    value = data.at(i)
                result[i] = Number(value) & 255
            }
            return result
        }
    } catch (e3) {}

    try {
        if (typeof data.toBase64 === "function")
            return decodeBase64(String(data.toBase64()))
    } catch (e4) {}

    throw new Error("QByteArray ne peut pas être converti en tableau d'octets")
}

function decodeBase64(text) {
    var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    var clean = String(text || "").replace(/[^A-Za-z0-9+/=]/g, "")
    var out = []
    var buffer = 0
    var bits = 0
    for (var i = 0; i < clean.length; ++i) {
        var ch = clean.charAt(i)
        if (ch === "=") break
        var value = alphabet.indexOf(ch)
        if (value < 0) continue
        buffer = (buffer << 6) | value
        bits += 6
        if (bits >= 8) {
            bits -= 8
            out.push((buffer >> bits) & 255)
        }
    }
    return new Uint8Array(out)
}

function u16(a, p) {
    return a[p] | (a[p + 1] << 8)
}

function u32(a, p) {
    return (a[p] |
           (a[p + 1] << 8) |
           (a[p + 2] << 16) |
           (a[p + 3] << 24)) >>> 0
}

function bytesToUtf8(bytes) {
    var a = toUint8Array(bytes)
    var out = []
    var chunk = ""

    function flush() {
        if (chunk.length > 0) {
            out.push(chunk)
            chunk = ""
        }
    }

    for (var i = 0; i < a.length; ) {
        var c = a[i++]
        var cp
        if (c < 0x80) {
            cp = c
        } else if ((c & 0xE0) === 0xC0 && i < a.length) {
            cp = ((c & 0x1F) << 6) | (a[i++] & 0x3F)
        } else if ((c & 0xF0) === 0xE0 && i + 1 < a.length) {
            cp = ((c & 0x0F) << 12) |
                 ((a[i++] & 0x3F) << 6) |
                 (a[i++] & 0x3F)
        } else if ((c & 0xF8) === 0xF0 && i + 2 < a.length) {
            cp = ((c & 0x07) << 18) |
                 ((a[i++] & 0x3F) << 12) |
                 ((a[i++] & 0x3F) << 6) |
                 (a[i++] & 0x3F)
        } else {
            cp = 0xFFFD
        }

        if (cp <= 0xFFFF) {
            chunk += String.fromCharCode(cp)
        } else {
            cp -= 0x10000
            chunk += String.fromCharCode(
                0xD800 + ((cp >> 10) & 0x3FF),
                0xDC00 + (cp & 0x3FF)
            )
        }

        if (chunk.length > 4096) flush()
    }

    flush()
    return out.join("")
}

function makeBitReader(data) {
    return {
        data: data,
        pos: 0,
        bitbuf: 0,
        bitcount: 0,

        bits: function(n) {
            while (this.bitcount < n) {
                if (this.pos >= this.data.length)
                    throw new Error("Flux DEFLATE tronqué")
                this.bitbuf |= this.data[this.pos++] << this.bitcount
                this.bitcount += 8
            }
            var mask = (1 << n) - 1
            var value = this.bitbuf & mask
            this.bitbuf >>>= n
            this.bitcount -= n
            return value
        },

        alignByte: function() {
            this.bitbuf = 0
            this.bitcount = 0
        }
    }
}

function makeOutput(expected) {
    var size = Math.max(1024, Number(expected) || 0)
    var buf = new Uint8Array(size)
    var length = 0

    return {
        push: function(value) {
            if (length >= buf.length) {
                var grown = new Uint8Array(buf.length * 2)
                grown.set(buf)
                buf = grown
            }
            buf[length++] = value & 255
        },

        copyDistance: function(distance, count) {
            if (distance <= 0 || distance > length)
                throw new Error("Distance DEFLATE invalide : " + distance)
            for (var i = 0; i < count; ++i)
                this.push(buf[length - distance])
        },

        result: function() {
            return buf.slice(0, length)
        }
    }
}

function reverseBits(value, length) {
    var reversed = 0
    for (var i = 0; i < length; ++i) {
        reversed = (reversed << 1) | (value & 1)
        value >>>= 1
    }
    return reversed
}

function buildHuffman(lengths) {
    var max = 0
    var i
    for (i = 0; i < lengths.length; ++i)
        if (lengths[i] > max) max = lengths[i]

    var count = new Array(max + 1)
    for (i = 0; i <= max; ++i) count[i] = 0
    for (i = 0; i < lengths.length; ++i)
        if (lengths[i] > 0) count[lengths[i]]++

    var next = new Array(max + 1)
    var code = 0
    count[0] = 0
    for (var bits = 1; bits <= max; ++bits) {
        code = (code + (count[bits - 1] || 0)) << 1
        next[bits] = code
    }

    var tables = new Array(max + 1)
    for (i = 0; i <= max; ++i) tables[i] = {}

    for (var symbol = 0; symbol < lengths.length; ++symbol) {
        var len = lengths[symbol]
        if (len !== 0) {
            var reversedCode = reverseBits(next[len], len)
            tables[len][reversedCode] = symbol
            next[len]++
        }
    }

    return { max: max, tables: tables }
}

function decodeSymbol(reader, tree) {
    var code = 0
    for (var len = 1; len <= tree.max; ++len) {
        code |= reader.bits(1) << (len - 1)
        var symbol = tree.tables[len][code]
        if (symbol !== undefined)
            return symbol
    }
    throw new Error("Code Huffman DEFLATE invalide")
}

var LENGTH_BASE = [
    3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,
    35,43,51,59,67,83,99,115,131,163,195,227,258
]
var LENGTH_EXTRA = [
    0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,
    3,3,3,3,4,4,4,4,5,5,5,5,0
]
var DIST_BASE = [
    1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,
    257,385,513,769,1025,1537,2049,3073,4097,6145,
    8193,12289,16385,24577
]
var DIST_EXTRA = [
    0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,
    7,7,8,8,9,9,10,10,11,11,12,12,13,13
]

function fixedTrees() {
    var lit = new Array(288)
    var dist = new Array(32)
    var i
    for (i = 0; i <= 143; ++i) lit[i] = 8
    for (; i <= 255; ++i) lit[i] = 9
    for (; i <= 279; ++i) lit[i] = 7
    for (; i <= 287; ++i) lit[i] = 8
    for (i = 0; i < 32; ++i) dist[i] = 5
    return { lit: buildHuffman(lit), dist: buildHuffman(dist) }
}

function dynamicTrees(reader) {
    var hlit = reader.bits(5) + 257
    var hdist = reader.bits(5) + 1
    var hclen = reader.bits(4) + 4
    var order = [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15]
    var codeLengths = new Array(19)
    var i
    for (i = 0; i < 19; ++i) codeLengths[i] = 0
    for (i = 0; i < hclen; ++i)
        codeLengths[order[i]] = reader.bits(3)

    var codeTree = buildHuffman(codeLengths)
    var total = hlit + hdist
    var lengths = []

    while (lengths.length < total) {
        var symbol = decodeSymbol(reader, codeTree)
        var repeat, previous

        if (symbol <= 15) {
            lengths.push(symbol)
        } else if (symbol === 16) {
            if (lengths.length === 0)
                throw new Error("Répétition DEFLATE invalide")
            repeat = reader.bits(2) + 3
            previous = lengths[lengths.length - 1]
            while (repeat-- > 0) lengths.push(previous)
        } else if (symbol === 17) {
            repeat = reader.bits(3) + 3
            while (repeat-- > 0) lengths.push(0)
        } else if (symbol === 18) {
            repeat = reader.bits(7) + 11
            while (repeat-- > 0) lengths.push(0)
        } else {
            throw new Error("Longueur de code DEFLATE invalide")
        }
    }

    return {
        lit: buildHuffman(lengths.slice(0, hlit)),
        dist: buildHuffman(lengths.slice(hlit, hlit + hdist))
    }
}

function inflateCompressedBlock(reader, output, trees) {
    while (true) {
        var symbol = decodeSymbol(reader, trees.lit)
        if (symbol < 256) {
            output.push(symbol)
            continue
        }
        if (symbol === 256) return

        var li = symbol - 257
        if (li < 0 || li >= LENGTH_BASE.length)
            throw new Error("Longueur DEFLATE invalide")

        var length = LENGTH_BASE[li]
        var le = LENGTH_EXTRA[li]
        if (le) length += reader.bits(le)

        var ds = decodeSymbol(reader, trees.dist)
        if (ds < 0 || ds >= DIST_BASE.length)
            throw new Error("Distance DEFLATE hors plage")

        var distance = DIST_BASE[ds]
        var de = DIST_EXTRA[ds]
        if (de) distance += reader.bits(de)

        output.copyDistance(distance, length)
    }
}

function inflateRaw(data, expectedSize) {
    var input = toUint8Array(data)
    var reader = makeBitReader(input)
    var output = makeOutput(expectedSize)
    var finalBlock = false

    while (!finalBlock) {
        finalBlock = reader.bits(1) !== 0
        var type = reader.bits(2)

        if (type === 0) {
            reader.alignByte()
            if (reader.pos + 4 > input.length)
                throw new Error("Bloc DEFLATE stocké tronqué")
            var len = input[reader.pos] | (input[reader.pos + 1] << 8)
            var nlen = input[reader.pos + 2] | (input[reader.pos + 3] << 8)
            reader.pos += 4
            if (((len ^ 0xFFFF) & 0xFFFF) !== nlen)
                throw new Error("Bloc DEFLATE stocké incohérent")
            if (reader.pos + len > input.length)
                throw new Error("Bloc DEFLATE stocké incomplet")
            for (var s = 0; s < len; ++s)
                output.push(input[reader.pos++])
        } else if (type === 1) {
            inflateCompressedBlock(reader, output, fixedTrees())
        } else if (type === 2) {
            inflateCompressedBlock(reader, output, dynamicTrees(reader))
        } else {
            throw new Error("Type de bloc DEFLATE réservé")
        }
    }

    return output.result()
}

function findEocd(bytes) {
    var min = Math.max(0, bytes.length - 65557)
    for (var p = bytes.length - 22; p >= min; --p) {
        if (u32(bytes, p) === 0x06054B50)
            return p
    }
    return -1
}

function readQgsFromQgz(binary) {
    var bytes = toUint8Array(binary)
    var eocd = findEocd(bytes)
    if (eocd < 0)
        throw new Error("Signature ZIP de fin d'archive introuvable")

    var entries = u16(bytes, eocd + 10)
    var centralOffset = u32(bytes, eocd + 16)
    var p = centralOffset
    var chosen = null

    for (var i = 0; i < entries; ++i) {
        if (p + 46 > bytes.length || u32(bytes, p) !== 0x02014B50)
            throw new Error("Répertoire central ZIP invalide")

        var flags = u16(bytes, p + 8)
        var method = u16(bytes, p + 10)
        var compressedSize = u32(bytes, p + 20)
        var uncompressedSize = u32(bytes, p + 24)
        var nameLength = u16(bytes, p + 28)
        var extraLength = u16(bytes, p + 30)
        var commentLength = u16(bytes, p + 32)
        var localOffset = u32(bytes, p + 42)
        var name = bytesToUtf8(bytes.slice(p + 46, p + 46 + nameLength))

        if (/\.qgs$/i.test(name) && !chosen) {
            chosen = {
                name: name,
                flags: flags,
                method: method,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localOffset: localOffset
            }
        }

        p += 46 + nameLength + extraLength + commentLength
    }

    if (!chosen)
        throw new Error("Aucun fichier .qgs dans le .qgz")

    var lp = chosen.localOffset
    if (lp + 30 > bytes.length || u32(bytes, lp) !== 0x04034B50)
        throw new Error("En-tête local ZIP invalide")

    var localNameLength = u16(bytes, lp + 26)
    var localExtraLength = u16(bytes, lp + 28)
    var dataStart = lp + 30 + localNameLength + localExtraLength
    var dataEnd = dataStart + chosen.compressedSize

    if (dataEnd > bytes.length)
        throw new Error("Entrée .qgs tronquée dans le .qgz")

    var compressed = bytes.slice(dataStart, dataEnd)
    var xmlBytes

    if (chosen.method === 0) {
        xmlBytes = compressed
    } else if (chosen.method === 8) {
        xmlBytes = inflateRaw(compressed, chosen.uncompressedSize)
    } else {
        throw new Error("Méthode ZIP non prise en charge : " + chosen.method)
    }

    if (chosen.uncompressedSize && xmlBytes.length !== chosen.uncompressedSize) {
        throw new Error(
            "Taille .qgs décompressée inattendue (" +
            xmlBytes.length + " / " + chosen.uncompressedSize + ")"
        )
    }

    return { name: chosen.name, text: bytesToUtf8(xmlBytes) }
}

