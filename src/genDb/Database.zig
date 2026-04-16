const std = @import("std");
const Organism = @import("Organism.zig");
const Self = @This();

kmers: []u64 = &.{},
taxons: []u32 = &.{},
k: u6,
organisms: std.array_hash_map.Auto(u32, Organism) = .empty,

pub fn init(k: u6) Self {
    return .{ .k = k };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    for (self.organisms.values()) |org| {
        allocator.free(org.name);
    }
    self.organisms.deinit(allocator);
    if (self.kmers.len > 0) allocator.free(self.kmers);
    if (self.taxons.len > 0) allocator.free(self.taxons);
}

pub fn loadOrganismsFromMemory(self: *Self, organisms: std.array_hash_map.Auto(u32, Organism)) void {
    self.organisms = organisms;
}

pub fn loadIndex(self: *Self, allocator: std.mem.Allocator, reader: *std.Io.Reader) !void {
    const k = try reader.takeInt(u8, .little);
    if (k != self.k) return error.KMismatch;
    const count = try reader.takeInt(u64, .little);

    self.kmers = try allocator.alloc(u64, count);
    self.taxons = try allocator.alloc(u32, count);

    for (0..count) |i| {
        self.kmers[i] = try reader.takeInt(u64, .little);
        self.taxons[i] = try reader.takeInt(u32, .little);
    }
}

pub fn getTaxon(self: *const Self, encoded_kmer: u64) ?u32 {
    const index = std.sort.binarySearch(u64, encoded_kmer, self.kmers, {}, struct {
        pub fn cmp(_: void, key: u64, item: u64) std.math.Order {
            return std.math.order(key, item);
        }
    }.cmp);
    return if (index) |i| self.taxons[i] else null;
}
