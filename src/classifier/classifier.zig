const std = @import("std");
const kmer = @import("../kmer.zig");
const Database = @import("../genDb.zig").Database;

pub const Result = struct {
    taxon_id: ?u32,
    hits: usize,
    total_kmers: usize,

    pub fn confidence(self: Result) f64 {
        if (self.total_kmers == 0) return 0.0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(self.total_kmers));
    }

    pub fn isClassified(self: Result) bool {
        return self.taxon_id != null and self.hits > 0;
    }
};

pub const Summary = struct {
    taxon_counts: []usize,
    total_reads: usize,
    classified_reads: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, num_taxons: usize) !Summary {
        const counts = try allocator.alloc(usize, num_taxons);
        @memset(counts, 0);
        return .{
            .taxon_counts = counts,
            .total_reads = 0,
            .classified_reads = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Summary) void {
        self.allocator.free(self.taxon_counts);
    }

    pub fn add(self: *Summary, result: Result) void {
        self.total_reads += 1;
        if (result.taxon_id) |id| {
            if (result.hits > 0) {
                self.classified_reads += 1;
                self.taxon_counts[id] += 1;
            }
        }
    }

    pub fn classificationRate(self: Summary) f64 {
        if (self.total_reads == 0) return 0.0;
        return @as(f64, @floatFromInt(self.classified_reads)) / @as(f64, @floatFromInt(self.total_reads));
    }
};

pub fn classify(sequence: []const u8, database: Database, hit_counts: []usize) Result {
    @memset(hit_counts, 0);

    var total_kmers: usize = 0;
    var extractor = kmer.extractor.extract(sequence, database.k, database.l);

    while (extractor.next()) |encoded| {
        total_kmers += 1;
        if (database.getTaxonId(encoded)) |taxon_id| {
            hit_counts[taxon_id] += 1;
        }
    }

    var best_taxon: ?u32 = null;
    var best_hits: usize = 0;

    for (hit_counts, 0..) |count, taxon_id| {
        if (count > best_hits) {
            best_hits = count;
            best_taxon = @intCast(taxon_id);
        }
    }

    return .{
        .taxon_id = best_taxon,
        .hits = best_hits,
        .total_kmers = total_kmers,
    };
}
