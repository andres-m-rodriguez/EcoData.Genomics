const std = @import("std");
const kmer = @import("../kmer.zig");
const Taxon = @import("Taxon.zig");
const seqio = @import("../seqio.zig");
const Self = @This();

look_up: kmer.Index,
k: u6,
l: u6,
taxons: std.ArrayList(Taxon) = .empty,
pub fn init(k: u6, l: u6) Self {
    return .{
        .look_up = kmer.Index.init(),
        .k = k,
        .l = l,
    };
}
pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.look_up.deinit(allocator);
    for (self.taxons.items) |taxon| {
        allocator.free(taxon.name);
    }
    self.taxons.deinit(allocator);
}
pub fn addFasta(self: *Self, allocator: std.mem.Allocator, reader: *std.Io.Reader) !void {
    const taxon_id: u32 = @intCast(self.taxons.items.len);
    var name: []const u8 = "";

    while (try seqio.Fasta.next(allocator, reader)) |record| {
        var rec = record;
        defer rec.deinit(allocator);

        try self.look_up.addSequence(allocator, record.sequences.data.items, taxon_id, self.k, self.l);
        if (name.len == 0) {
            name = try allocator.dupe(u8, record.header);
        }
    }

    try self.taxons.append(allocator, Taxon{ .name = name });
}
pub fn merge(self: *Self, allocator: std.mem.Allocator, other: *Self) !void {
    const taxon_offset: u32 = @intCast(self.taxons.items.len);

    for (other.taxons.items) |taxon| {
        try self.taxons.append(allocator, Taxon{ .name = try allocator.dupe(u8, taxon.name) });
    }

    for (other.look_up.map.keys(), other.look_up.map.values()) |key, val| {
        const entry = try self.look_up.map.getOrPut(allocator, key);
        if (!entry.found_existing) {
            entry.value_ptr.* = val + taxon_offset;
        }
    }
}

pub fn build(self: *Self, writer: *std.Io.Writer) !void {
    self.look_up.sort();

    // Header
    try writer.writeInt(u8, self.k, .little);
    try writer.writeInt(u8, self.l, .little);
    try writer.writeAll(&[_]u8{0} ** 6);
    try writer.writeInt(u64, self.look_up.map.count(), .little);

    // K-mers
    for (self.look_up.map.keys()) |key| {
        try writer.writeInt(u64, key, .little);
    }

    // Taxon IDs
    for (self.look_up.map.values()) |val| {
        try writer.writeInt(u32, val, .little);
    }

    // Taxon count
    try writer.writeInt(u32, @intCast(self.taxons.items.len), .little);

    // Taxon names
    for (self.taxons.items) |taxon| {
        try writer.writeInt(u16, @intCast(taxon.name.len), .little);
        try writer.writeAll(taxon.name);
    }

    try writer.flush();
}
