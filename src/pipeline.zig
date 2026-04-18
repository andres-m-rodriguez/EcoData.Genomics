const std = @import("std");
const EcoData_Genomics = @import("root.zig");
const seqio = EcoData_Genomics.seqio;
const kmer = EcoData_Genomics.kmer;
const genDb = EcoData_Genomics.genDb;
const classifier = EcoData_Genomics.classifier;
const trimmer = @import("trimmer.zig");

pub const Pipeline = struct {
    io: std.Io,
    gpa: std.mem.Allocator,
    console: *std.Io.Writer,
    step: usize = 0,
    total_steps: usize,

    pub fn init(io: std.Io, gpa: std.mem.Allocator, console: *std.Io.Writer, total_steps: usize) Pipeline {
        return .{ .io = io, .gpa = gpa, .console = console, .total_steps = total_steps };
    }

    pub fn begin(self: *Pipeline, comptime name: []const u8) void {
        self.step += 1;
        self.console.print("[{}/{}] {s}...\n", .{ self.step, self.total_steps, name }) catch {};
        self.console.flush() catch {};
    }

    pub fn done(self: *Pipeline, comptime fmt: []const u8, args: anytype) void {
        self.console.print("       " ++ fmt ++ "\n", args) catch {};
        self.console.flush() catch {};
    }
};

pub fn buildDatabase(p: *Pipeline, references: []const []const u8, output_path: []const u8) !genDb.Database {
    p.begin("Building database");

    var builder = genDb.Builder.init(kmer.K.kraken2_k, kmer.K.kraken2_l);
    defer builder.deinit(p.gpa);
    try builder.look_up.map.ensureTotalCapacity(p.gpa, 2_000_000);

    for (references) |path| {
        try loadFastaToBuilder(p.io, p.gpa, &builder, path);
    }

    const output_file = try std.Io.Dir.cwd().createFile(p.io, output_path, .{});
    defer output_file.close(p.io);
    var output_buffer: [128 * 1024]u8 = undefined;
    var output_writer = output_file.writer(p.io, &output_buffer);
    try builder.build(&output_writer.interface);

    p.done("Indexed {} references, {} k-mers", .{ references.len, builder.look_up.map.count() });

    p.begin("Loading database");

    var database = genDb.Database.init(kmer.K.kraken2_k, kmer.K.kraken2_l);
    try database.loadFromFile(p.io, p.gpa, output_path);

    p.done("Loaded {} k-mers, {} taxons", .{ database.kmers.len, database.taxons.len });

    return database;
}

pub fn loadReads(p: *Pipeline, reads_path: []const u8) ![]seqio.Fastq.Record {
    p.begin("Loading reads");

    const reads_file = try std.Io.Dir.cwd().openFile(p.io, reads_path, .{});
    defer reads_file.close(p.io);
    var reads_buffer: [128 * 1024]u8 = undefined;
    var reads_reader = reads_file.reader(p.io, &reads_buffer);

    var decompress_buf: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(&reads_reader.interface, .gzip, &decompress_buf);

    var records: std.ArrayList(seqio.Fastq.Record) = .empty;
    while (try seqio.Fastq.next(&decompressor.reader, p.gpa, .alloc_always)) |record| {
        try records.append(p.gpa, record);
    }

    p.done("Loaded {} reads", .{records.items.len});

    return records.toOwnedSlice(p.gpa);
}

pub const TrimmedRead = struct {
    sequence: []const u8,
    quality: []const u8,
};

pub fn trimReads(p: *Pipeline, reads: []const seqio.Fastq.Record) ![]TrimmedRead {
    p.begin("Trimming reads");

    const options = trimmer.Trimmer.Options{};
    var trimmed: std.ArrayList(TrimmedRead) = .empty;
    var discarded: usize = 0;

    for (reads) |record| {
        const seq = record.sequence();
        const qual = record.quality();
        if (trimmer.Trimmer.trim(qual, options)) |cut_len| {
            try trimmed.append(p.gpa, .{
                .sequence = seq[0..cut_len],
                .quality = qual[0..cut_len],
            });
        } else {
            discarded += 1;
        }
    }

    p.done("Kept: {}, Discarded: {}", .{ trimmed.items.len, discarded });

    return trimmed.toOwnedSlice(p.gpa);
}

pub fn classifyReads(p: *Pipeline, database: genDb.Database, reads: []const TrimmedRead) !void {
    p.begin("Classifying reads");

    const num_taxons = database.taxons.len;
    const hit_counts = try p.gpa.alloc(usize, num_taxons);
    defer p.gpa.free(hit_counts);

    var summary = try classifier.Summary.init(p.gpa, num_taxons);
    defer summary.deinit();

    var total_kmers: usize = 0;
    var total_hits: usize = 0;
    var min_confidence: f64 = 1.0;
    var max_confidence: f64 = 0.0;
    var sum_confidence: f64 = 0.0;

    for (reads) |record| {
        const result = classifier.classify(record.sequence, database, hit_counts);
        summary.add(result);

        total_kmers += result.total_kmers;
        total_hits += result.hits;

        if (result.isClassified()) {
            const conf = result.confidence();
            if (conf < min_confidence) min_confidence = conf;
            if (conf > max_confidence) max_confidence = conf;
            sum_confidence += conf;
        }
    }

    const avg_confidence = if (summary.classified_reads > 0)
        sum_confidence / @as(f64, @floatFromInt(summary.classified_reads))
    else
        0.0;

    p.done("K-mers extracted: {}, Hits: {} ({d:.1}%)", .{
        total_kmers,
        total_hits,
        @as(f64, @floatFromInt(total_hits)) / @as(f64, @floatFromInt(total_kmers)) * 100.0,
    });
    p.done("Classified: {}, Unclassified: {}", .{ summary.classified_reads, summary.total_reads - summary.classified_reads });
    p.done("Confidence: min={d:.1}%, avg={d:.1}%, max={d:.1}%", .{
        min_confidence * 100.0,
        avg_confidence * 100.0,
        max_confidence * 100.0,
    });

    for (database.taxons, 0..) |taxon, i| {
        const count = summary.taxon_counts[i];
        if (count > 0) {
            const pct = @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(summary.total_reads)) * 100.0;
            p.done("{s}: {} reads ({d:.1}%)", .{ taxon.name, count, pct });
        }
    }
}

fn loadFastaToBuilder(io: std.Io, allocator: std.mem.Allocator, builder: *genDb.Builder, path: []const u8) !void {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var file_buffer: [128 * 1024]u8 = undefined;
    var file_reader = file.reader(io, &file_buffer);

    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(&file_reader.interface, .gzip, &decompress_buffer);

    try builder.addFasta(allocator, &decompressor.reader);
}
