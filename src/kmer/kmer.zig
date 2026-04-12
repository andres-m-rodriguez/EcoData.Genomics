const std = @import("std");
const Self = @This();

map: std.AutoArrayHashMapUnmanaged(u64, u64) = .empty,
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

test "count kmers" {
    var kmer = Self.init();
    defer kmer.deinit(std.testing.allocator);
    try kmer.add(std.testing.allocator, "ATCGAT", 3);
    try std.testing.expectEqual(@as(u64, 1), kmer.get("ATC").?);
    try std.testing.expectEqual(@as(u64, 1), kmer.get("TCG").?);
    try std.testing.expectEqual(@as(u64, 1), kmer.get("CGA").?);
    try std.testing.expectEqual(@as(u64, 1), kmer.get("GAT").?);
    try std.testing.expectEqual(@as(usize, 4), kmer.map.count());
}

test "skips kmers with N" {
    var kmer = Self.init();
    defer kmer.deinit(std.testing.allocator);

    try kmer.add(std.testing.allocator, "ATNGAT", 3);

    // "ATN", "TNG", "NGA" should be skipped
    try std.testing.expectEqual(@as(?u64, null), kmer.get("ATN"));
    try std.testing.expectEqual(@as(u64, 1), kmer.get("GAT").?);
    try std.testing.expectEqual(@as(usize, 1), kmer.map.count());
}
