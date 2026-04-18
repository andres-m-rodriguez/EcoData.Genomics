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

        while (self.i + k <= self.sequence.len) {
            const i = self.i;
            self.i += 1;

            if (!self.started) {
                const first_l = encode(self.sequence[i..][0..l]) orelse continue;
                self.encs[0] = first_l;

                var valid = true;
                for (1..n) |j| {
                    const bits = encoding.encodeBase(self.sequence[i + j + l - 1]) orelse {
                        valid = false;
                        break;
                    };
                    self.encs[j] = ((self.encs[j - 1] << 2) | bits) & self.mask;
                }
                if (!valid) continue;
                self.started = true;
            } else {
                const bits = encoding.encodeBase(self.sequence[i + k - 1]) orelse {
                    self.started = false;
                    continue;
                };
                for (0..n - 1) |j| self.encs[j] = self.encs[j + 1];
                self.encs[n - 1] = ((self.encs[n - 2] << 2) | bits) & self.mask;
            }

            var min = self.encs[0];
            for (1..n) |j| if (self.encs[j] < min) {
                min = self.encs[j];
            };
            return min;
        }
        return null;
    }
};
