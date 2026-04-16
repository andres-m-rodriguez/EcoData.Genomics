const std = @import("std");
const kmer = @import("../kmer.zig");
const Organism = @import("Organism.zig");
const Database = @import("Database.zig");
const seqio = @import("../seqio.zig");
const Self = @This();

look_up: kmer.Index,
k: u6,
organisms: std.array_hash_map.Auto(u32, Organism) = .empty,

pub fn init(k: u6) Self {
    return .{
        .look_up = kmer.Index.init(),
        .k = k,
    };
}
pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.look_up.deinit(allocator);
    for (self.organisms.values()) |org| {
        allocator.free(org.name);
    }
    self.organisms.deinit(allocator);
}
pub fn addFasta(self: *Self, allocator: std.mem.Allocator, reader: *std.Io.Reader, taxon_id: u32) !void {
    while (try seqio.Fasta.next(allocator, reader)) |record| {
        var rec = record;
        defer rec.deinit(allocator);

        try self.look_up.addSequence(allocator, record.sequences.data.items, taxon_id, self.k);
        const name = try allocator.dupe(u8, record.header);
        try self.organisms.put(allocator, taxon_id, Organism{ .name = name });
    }
}
pub const BuildOptions = struct {
    writer: ?*std.Io.Writer = null,
    transfer_organisms: bool = true,
};

pub fn build(self: *Self, options: BuildOptions) !?Database {
    if (options.writer) |writer| {
        self.look_up.sort();

        try writer.writeInt(u8, self.k, .little);
        try writer.writeAll(&[_]u8{0} ** 7);
        try writer.writeInt(u64, self.look_up.map.count(), .little);

        for (self.look_up.map.keys()) |key| {
            try writer.writeInt(u64, key, .little);
        }

        for (self.look_up.map.values()) |val| {
            try writer.writeInt(u32, val, .little);
        }

        try writer.flush();
    }

    if (!options.transfer_organisms) {
        return null;
    }

    var db = Database.init(self.k);
    db.loadOrganismsFromMemory(self.organisms);
    self.organisms = .empty;

    return db;
}
