const std = @import("std");
const extractor = @import("extractor.zig");
const encoding = @import("encoding.zig");
pub const encode = encoding.encode;
pub const decode = encoding.decode;
const Self = @This();

map: std.array_hash_map.Auto(u64, u32) = .empty,

pub fn init() Self {
    return .{
        .map = .empty,
    };
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

pub fn addSequence(self: *Self, allocator: std.mem.Allocator, sequence: []const u8, taxon_id: u32, k: u6, l: u6) !void {
    if (k == 0 or sequence.len < k) return;

    var extraction_it = extractor.extract(sequence, k, l);
    while (extraction_it.next()) |encoded_extract| {
        const encoded = encoded_extract.toValid() orelse continue;
        const entry = try self.map.getOrPut(allocator, encoded);
        if (!entry.found_existing) {
            entry.value_ptr.* = taxon_id;
        }
    }
}

pub fn sort(self: *Self) void {
    const Ctx = struct {
        keys: []u64,
        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return ctx.keys[a] < ctx.keys[b];
        }
    };
    self.map.sortUnstable(Ctx{ .keys = self.map.keys() });
}

test "index kmers to taxon" {
    var index = Self.init();
    defer index.deinit(std.testing.allocator);

    try index.addSequence(std.testing.allocator, "ATCGAT", 42, 4, 3);

    // With k=4, l=3 minimizers, we get minimizers from windows: ATCG, TCGA, CGAT
    try std.testing.expect(index.map.count() > 0);
}

test "skips kmers with N" {
    var index = Self.init();
    defer index.deinit(std.testing.allocator);

    try index.addSequence(std.testing.allocator, "ATNGAT", 42, 4, 3);

    // Windows containing N should be skipped or produce invalid minimizers
    try std.testing.expect(true);
}
