const std = @import("std");
const encoding = @import("encoding.zig");
pub const encode = encoding.encode;
pub const decode = encoding.decode;

pub fn extract(sequence: []const u8, k: u6, l: u6) Iterator {
    return Iterator{
        .sequence = sequence,
        .k = k,
        .i = 0,
        .l = l,
    };
}
pub const Result = union(enum) {
    valid: u64,
    invalid: usize,
    pub fn toValid(self: Result) ?u64 {
        return switch (self) {
            .valid => |v| v,
            .invalid => null,
        };
    }
};
pub const Iterator = struct {
    sequence: []const u8,
    i: usize,
    k: u6,
    l: u6,
    pub fn next(self: *Iterator) ?Result {
        if (self.i + self.k > self.sequence.len)
            return null;

        defer self.i += 1;

        const window = self.sequence[self.i..][0..self.k];

        var min: ?u64 = null;

        for (0..self.k - self.l + 1) |j| {
            const encoded = encode(window[j..][0..self.l]) orelse continue;
            if (min == null or encoded < min.?) {
                min = encoded;
            }
        }

        if (min) |m| return .{ .valid = m };
        return .{ .invalid = self.i };
    }
};
