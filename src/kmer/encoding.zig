pub fn encode(kmer: []const u8) ?u64 {
    var result: u64 = 0;
    for (kmer) |base| {
        const bits: u64 = switch (base) {
            'A', 'a' => 0b00,
            'C', 'c' => 0b01,
            'G', 'g' => 0b10,
            'T', 't' => 0b11,
            else => return null,
        };
        result = (result << 2) | bits;
    }
    return result;
}

pub fn decode(encoded: u64, k: u6, buf: []u8) []u8 {
    var val = encoded;
    var pos: usize = k;
    while (pos > 0) {
        pos -= 1;
        buf[pos] = "ACGT"[@as(usize, @truncate(val & 0b11))];
        val >>= 2;
    }
    return buf[0..k];
}
