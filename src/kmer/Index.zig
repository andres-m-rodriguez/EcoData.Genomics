const std = @import("std");
const encoding = @import("encoding.zig");

pub const encode = encoding.encode;
pub const decode = encoding.decode;

const Self = @This();

map: std.array_hash_map.Auto(u64, u32) = .empty,

pub fn init() Self {
    return .{ .map = .empty,};
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.map.deinit(allocator);
}

pub fn getTaxon(self: *Self, kmer: []const u8) ?u32 {
    const encoded = encode(kmer) orelse return null;
    return self.map.get(encoded);
}

pub fn getTaxonEncoded(self: *Self, encoded: u64) ?u32 {
    return self.map.get(encoded);
}

pub fn addSequence(self: *Self, allocator: std.mem.Allocator, sequence: []const u8, taxon_id: u32, k: u6) !void {
    if (k == 0 or sequence.len < k) return;

    var i: usize = 0;
    while (i + k <= sequence.len) : (i += 1) {
        const encoded = encode(sequence[i..][0..k]) orelse continue;
        const entry = try self.map.getOrPut(allocator, encoded);
        if (!entry.found_existing) {
            entry.value_ptr.* = taxon_id;
        }
        // If already exists, keep the first taxon (don't overwrite)
    }
}

test "index kmers to taxon" {
    var index = Self.init();
    defer index.deinit(std.testing.allocator);

    try index.addSequence(std.testing.allocator, "ATCGAT", 42, 3);

    try std.testing.expectEqual(@as(u32, 42), index.getTaxon("ATC").?);
    try std.testing.expectEqual(@as(u32, 42), index.getTaxon("TCG").?);
    try std.testing.expectEqual(@as(u32, 42), index.getTaxon("GAT").?);
}

test "skips kmers with N" {
    var index = Self.init();
    defer index.deinit(std.testing.allocator);

    try index.addSequence(std.testing.allocator, "ATNGAT", 42, 3);

    try std.testing.expectEqual(@as(?u32, null), index.getTaxon("ATN"));
    try std.testing.expectEqual(@as(u32, 42), index.getTaxon("GAT").?);
}
