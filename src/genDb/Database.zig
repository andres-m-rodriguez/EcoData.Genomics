const std = @import("std");
const Organism = @import("Organism.zig");
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
    allocated: struct {
        kmers: []u64,
        taxons: []u32,
    },
};

index: IndexData = .none,
kmers: []const u64 = &.{},
taxons: []const u32 = &.{},
k: u6,
organisms: std.array_hash_map.Auto(u32, Organism) = .empty,

pub fn init(k: u6) Self {
    return .{ .k = k };
}

pub fn deinit(self: *Self, io: Io, allocator: std.mem.Allocator) void {
    for (self.organisms.values()) |org| {
        allocator.free(org.name);
    }
    self.organisms.deinit(allocator);

    switch (self.index) {
        .none => {},
        .mapped => |*m| {
            m.mapping.destroy(io);
            m.file.close(io);
        },
        .allocated => |a| {
            allocator.free(a.kmers);
            allocator.free(a.taxons);
        },
    }
}

pub fn loadOrganismsFromMemory(self: *Self, organisms: std.array_hash_map.Auto(u32, Organism)) void {
    self.organisms = organisms;
}

pub fn loadIndexFromFile(self: *Self, io: Io, path: []const u8) !void {
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

    const count = std.mem.readInt(u64, data[8..16], .little);

    const kmers_start = 16;
    const kmers_end = kmers_start + count * 8;
    const kmers_bytes = data[kmers_start..kmers_end];
    self.kmers = @as([*]const u64, @ptrCast(@alignCast(kmers_bytes.ptr)))[0..count];

    const taxons_end = kmers_end + count * 4;
    const taxons_bytes = data[kmers_end..taxons_end];
    self.taxons = @as([*]const u32, @ptrCast(@alignCast(taxons_bytes.ptr)))[0..count];

    self.index = .{ .mapped = .{ .file = file, .mapping = mm } };
}

pub fn loadIndex(self: *Self, allocator: std.mem.Allocator, reader: *Io.Reader) !void {
    // Header: k (1 byte) + padding (7 bytes) + count (8 bytes) = 16 bytes
    const header = try reader.takeArray(16);
    const k = header[0];
    if (k != self.k) return error.KMismatch;

    const count = std.mem.readInt(u64, header[8..16], .little);

    const kmers = try allocator.alloc(u64, count);
    errdefer allocator.free(kmers);
    const taxons = try allocator.alloc(u32, count);
    errdefer allocator.free(taxons);

    for (0..count) |i| {
        kmers[i] = try reader.takeInt(u64, .little);
    }
    for (0..count) |i| {
        taxons[i] = try reader.takeInt(u32, .little);
    }

    self.kmers = kmers;
    self.taxons = taxons;
    self.index = .{ .allocated = .{ .kmers = kmers, .taxons = taxons } };
}

pub fn getTaxon(self: *const Self, encoded_kmer: u64) ?u32 {
    const index = std.sort.binarySearch(u64, self.kmers, encoded_kmer, struct {
        pub fn cmp(key: u64, item: u64) std.math.Order {
            return std.math.order(key, item);
        }
    }.cmp);
    return if (index) |i| self.taxons[i] else null;
}
