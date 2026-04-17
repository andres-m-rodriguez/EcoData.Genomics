const std = @import("std");
const Taxon = @import("Taxon.zig");
const Self = @This();

const Io = std.Io;
const File = Io.File;
const MemoryMap = File.MemoryMap;

const IndexData = union(enum) {
    none,
    mapped: struct {
        file: File,
        mapping: MemoryMap,
    },
};

index: IndexData = .none,
kmers: []const u64 = &.{},
taxon_ids: []const u32 = &.{},
k: u6,
l: u6,
taxons: []const Taxon = &.{},

pub fn init(k: u6, l: u6) Self {
    return .{ .k = k, .l = l };
}

pub fn deinit(self: *Self, io: Io, allocator: std.mem.Allocator) void {
    for (self.taxons) |taxon| {
        allocator.free(taxon.name);
    }
    allocator.free(self.taxons);

    switch (self.index) {
        .none => {},
        .mapped => |*m| {
            m.mapping.destroy(io);
            m.file.close(io);
        },
    }
}

pub fn loadFromFile(self: *Self, io: Io, allocator: std.mem.Allocator, path: []const u8) !void {
    const file = try Io.Dir.cwd().openFile(io, path, .{});
    errdefer file.close(io);

    const stat = try file.stat(io);
    const size: usize = @intCast(stat.size);

    var mm = try MemoryMap.create(io, file, .{
        .len = size,
        .protection = .{ .read = true, .write = false },
    });
    errdefer mm.destroy(io);

    const data = mm.memory;

    const k = data[0];
    if (k != self.k) return error.KMismatch;

    const l = data[1];
    if (l != self.l) return error.LMismatch;

    const kmer_count = std.mem.readInt(u64, data[8..16], .little);

    // K-mers
    const kmers_start = 16;
    const kmers_end = kmers_start + kmer_count * 8;
    const kmers_bytes = data[kmers_start..kmers_end];
    self.kmers = @as([*]const u64, @ptrCast(@alignCast(kmers_bytes.ptr)))[0..kmer_count];

    // Taxon IDs
    const taxon_ids_end = kmers_end + kmer_count * 4;
    const taxon_ids_bytes = data[kmers_end..taxon_ids_end];
    self.taxon_ids = @as([*]const u32, @ptrCast(@alignCast(taxon_ids_bytes.ptr)))[0..kmer_count];

    // Taxon count
    const taxon_count = std.mem.readInt(u32, data[taxon_ids_end..][0..4], .little);

    // Taxon names (variable length, need to allocate)
    const taxons = try allocator.alloc(Taxon, taxon_count);
    errdefer allocator.free(taxons);

    var pos: usize = taxon_ids_end + 4;
    for (0..taxon_count) |i| {
        const name_len = std.mem.readInt(u16, data[pos..][0..2], .little);
        pos += 2;
        taxons[i] = .{ .name = try allocator.dupe(u8, data[pos..][0..name_len]) };
        pos += name_len;
    }

    self.taxons = taxons;
    self.index = .{ .mapped = .{ .file = file, .mapping = mm } };
}

pub fn getTaxonId(self: *const Self, encoded_kmer: u64) ?u32 {
    const index = std.sort.binarySearch(u64, self.kmers, encoded_kmer, struct {
        pub fn cmp(key: u64, item: u64) std.math.Order {
            return std.math.order(key, item);
        }
    }.cmp);
    return if (index) |i| self.taxon_ids[i] else null;
}

pub fn getTaxon(self: *const Self, taxon_id: u32) ?Taxon {
    if (taxon_id < self.taxons.len) {
        return self.taxons[taxon_id];
    }
    return null;
}
