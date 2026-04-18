const encoding = @import("encoding.zig");
pub const encode = encoding.encode;
pub const decode = encoding.decode;

pub fn extract(sequence: []const u8, k: u6, l: u6) Iterator {
    return Iterator{
        .sequence = sequence,
        .i = 0,
        .k = k,
        .l = l,
        .mask = (@as(u64, 1) << @as(u6, l * 2)) - 1,
        .encs = [_]u64{0} ** 64,
        .started = false,
    };
}

pub const Iterator = struct {
    sequence: []const u8,
    i: usize,
    k: u6,
    l: u6,
    mask: u64,
    encs: [64]u64,
    started: bool,

    pub fn next(self: *Iterator) ?u64 {
        const k: usize = self.k;
        const l: usize = self.l;
        const n = k - l + 1;

        if (self.i + k > self.sequence.len)
            return null;

        defer self.i += 1;

        if (!self.started) {
            self.started = true;
            self.encs[0] = encode(self.sequence[self.i..][0..l]).?;
            for (1..n) |j| {
                const bits = encoding.encodeBase(self.sequence[self.i + j + l - 1]).?;
                self.encs[j] = ((self.encs[j - 1] << 2) | bits) & self.mask;
            }
        } else {
            const bits = encoding.encodeBase(self.sequence[self.i + k - 1]).?;
            for (0..n - 1) |j| self.encs[j] = self.encs[j + 1];
            self.encs[n - 1] = ((self.encs[n - 2] << 2) | bits) & self.mask;
        }

        var min = self.encs[0];
        for (1..n) |j| if (self.encs[j] < min) {
            min = self.encs[j];
        };
        return min;
    }
};
