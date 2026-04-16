const std = @import("std");
const kmer = @import("../kmer.zig");
const seqio = @import("../seqio.zig");
const Organism = @import("Organism.zig");
const Self = @This();

look_up: kmer.Index = .{},
k: u6,
organisms: std.array_hash_map.Auto(u32, Organism) = .empty,

pub fn init(k: u6) Self {
    return .{ .k = k };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.organisms.deinit(allocator);
    self.look_up.deinit(allocator);
}

pub fn loadOrganismsFromMemory(self: *Self, organisms: std.array_hash_map.Auto(u32, Organism)) void {
    self.organisms = organisms;
}
pub fn loadIndex(self: *Self, allocator: std.mem.Allocator, reader: *std.Io.Reader) !void {
    const k = try reader.takeInt(u8, .little);
    if (k != self.k) return error.KMismatch;
    const count = try reader.takeInt(u64, .little);
    for (0..count) |_| {
        const kmer_i = try reader.takeInt(u64, .little);
        const taxon = try reader.takeInt(u32, .little);
        try self.look_up.map.put(allocator, kmer_i, taxon);
    }
}
pub fn loadIndexFromMemory(self: *Self, index: kmer.Index) void {
    self.look_up = index;
}
