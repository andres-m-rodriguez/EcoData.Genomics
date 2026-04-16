const std = @import("std");
const encoding = @import("encoding.zig");

pub const encode = encoding.encode;
pub const decode = encoding.decode;

const Self = @This();

map: std.array_hash_map.Auto(u64, u64) = .empty,

pub fn init() Self {
    return .{ .map = .empty };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.map.deinit(allocator);
}

pub fn get(self: *Self, kmer: []const u8) ?u64 {
    const encoded = encode(kmer) orelse return null;
    return self.map.get(encoded);
}

pub fn getEncoded(self: *Self, encoded: u64) ?u64 {
    return self.map.get(encoded);
}

pub fn add(self: *Self, allocator: std.mem.Allocator, sequence: []const u8, k: u6) !void {
    if (k == 0 or sequence.len < k) return;

    var i: usize = 0;
    while (i + k <= sequence.len) : (i += 1) {
        const encoded = encode(sequence[i..][0..k]) orelse continue;
        const entry = try self.map.getOrPut(allocator, encoded);
        if (!entry.found_existing) {
            entry.value_ptr.* = 1;
        } else {
            entry.value_ptr.* += 1;
        }
    }
}

test "count kmers" {
    var counter = Self.init();
    defer counter.deinit(std.testing.allocator);
    try counter.add(std.testing.allocator, "ATCGAT", 3);
    try std.testing.expectEqual(@as(u64, 1), counter.get("ATC").?);
    try std.testing.expectEqual(@as(u64, 1), counter.get("TCG").?);
    try std.testing.expectEqual(@as(u64, 1), counter.get("CGA").?);
    try std.testing.expectEqual(@as(u64, 1), counter.get("GAT").?);
    try std.testing.expectEqual(@as(usize, 4), counter.map.count());
}

test "skips kmers with N" {
    var counter = Self.init();
    defer counter.deinit(std.testing.allocator);

    try counter.add(std.testing.allocator, "ATNGAT", 3);

    try std.testing.expectEqual(@as(?u64, null), counter.get("ATN"));
    try std.testing.expectEqual(@as(u64, 1), counter.get("GAT").?);
    try std.testing.expectEqual(@as(usize, 1), counter.map.count());
}
