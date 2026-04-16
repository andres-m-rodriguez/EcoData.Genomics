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
    self.organisms.deinit(allocator);
}
pub fn addFasta(self: *Self, allocator: std.mem.Allocator, reader: *std.Io.Reader, taxon_id: u32) !void {
    while (try seqio.Fasta.next(allocator, reader)) |record| {
        var rec = record;
        defer rec.deinit(allocator);

        try self.look_up.addSequence(allocator, record.sequences.data.items, taxon_id, self.k);
        try self.organisms.put(allocator, taxon_id, Organism{ .name = record.header });
    }
}
pub const BuildOptions = struct {
    writer: ?*std.Io.Writer = null,
    transfer_organisms: bool = true,
    transfer_index: bool = true,
};

pub fn build(self: *Self, options: BuildOptions) !?Database {
    if (options.writer) |writer| {
        try writer.writeInt(u8, self.k, .little);
        try writer.writeInt(u64, self.look_up.map.count(), .little);

        var it = self.look_up.map.iterator();
        while (it.next()) |entry| {
            try writer.writeInt(u64, entry.key_ptr.*, .little);
            try writer.writeInt(u32, entry.value_ptr.*, .little);
        }
        try writer.flush();
    }

    if (!options.transfer_organisms and !options.transfer_index) {
        return null;
    }

    var db = Database.init(self.k);

    if (options.transfer_organisms) {
        db.loadOrganismsFromMemory(self.organisms);
        self.organisms = .empty;
    }

    if (options.transfer_index) {
        db.loadIndexFromMemory(self.look_up);
        self.look_up = .{};
    }

    return db;
}
