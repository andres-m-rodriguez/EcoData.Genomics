const std = @import("std");
const EcoData_Genomics = @import("root.zig");
const seqio = EcoData_Genomics.seqio;
const kmer = EcoData_Genomics.kmer;
const genDb = EcoData_Genomics.genDb;
const classifier = EcoData_Genomics.classifier;
const trimmer = @import("trimmer.zig");

pub const TrimmedRead = trimmer.TrimmedRead;

const reference_files = [_][]const u8{
    "data/reference_genomes/ecoli_k12.fna.gz",
    "data/reference_genomes/legionella_pneumophila.fna.gz",
    "data/reference_genomes/pseudomonas_aeruginosa.fna.gz",
    "data/reference_genomes/salmonella_enterica.fna.gz",
    "data/reference_genomes/vibrio_cholerae.fna.gz",
};

pub fn buildDatabase(io: std.Io, gpa: std.mem.Allocator, output_path: []const u8) !genDb.Database {
    if (!dbExists(io, output_path)) {
        var builder = genDb.Builder.init(kmer.K.kraken2_k, kmer.K.kraken2_l);
        defer builder.deinit(gpa);

        for (reference_files) |path| {
            try loadFastaGzip(io, gpa, &builder, path);
        }

        const output_file = try std.Io.Dir.cwd().createFile(io, output_path, .{});
        defer output_file.close(io);
        var output_buffer: [128 * 1024]u8 = undefined;
        var output_writer = output_file.writer(io, &output_buffer);
        try builder.build(&output_writer.interface);
    }

    var database = genDb.Database.init(kmer.K.kraken2_k, kmer.K.kraken2_l);
    try database.loadFromFile(io, gpa, output_path);
    return database;
}

pub fn loadAndTrimReads(io: std.Io, gpa: std.mem.Allocator, reads_path: []const u8) ![]TrimmedRead {
    const file = try std.Io.Dir.cwd().openFile(io, reads_path, .{});
    defer file.close(io);
    var file_buffer: [128 * 1024]u8 = undefined;
    var file_reader = file.reader(io, &file_buffer);

    var decompress_buf: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(&file_reader.interface, .gzip, &decompress_buf);

    const options = trimmer.Trimmer.Options{};
    var trimmed: std.ArrayList(TrimmedRead) = .empty;

    while (try seqio.Fastq.next(&decompressor.reader, gpa, .alloc_always)) |record| {
        const seq = record.sequence();
        const qual = record.quality();
        if (trimmer.Trimmer.trim(qual, options)) |cut_len| {
            try trimmed.append(gpa, .{
                .sequence = seq[0..cut_len],
                .quality = qual[0..cut_len],
            });
        }
    }

    return trimmed.toOwnedSlice(gpa);
}

pub fn classifyReads(io: std.Io, gpa: std.mem.Allocator, print: *std.Io.Writer, database: genDb.Database, reads: []const TrimmedRead) !void {
    _ = io;

    const num_taxons = database.taxons.len;
    const hit_counts = try gpa.alloc(usize, num_taxons);
    defer gpa.free(hit_counts);

    var summary = try classifier.Summary.init(gpa, num_taxons);
    defer summary.deinit();

    var total_kmers: usize = 0;
    var total_hits: usize = 0;

    for (reads) |record| {
        const result = classifier.classify(record.sequence, database, hit_counts);
        summary.add(result);
        total_kmers += result.total_kmers;
        total_hits += result.hits;
    }

    const hit_pct = if (total_kmers > 0) @as(f64, @floatFromInt(total_hits)) / @as(f64, @floatFromInt(total_kmers)) * 100.0 else 0.0;

    try print.print("       K-mers: {}, Hits: {} ({d:.1}%)\n", .{ total_kmers, total_hits, hit_pct });
    try print.print("       Classified: {}/{}\n", .{ summary.classified_reads, summary.total_reads });

    for (database.taxons, 0..) |taxon, i| {
        const count = summary.taxon_counts[i];
        if (count > 0) {
            const pct = @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(summary.total_reads)) * 100.0;
            try print.print("       {s}: {} ({d:.1}%)\n", .{ taxon.name, count, pct });
        }
    }
    try print.flush();
}

fn dbExists(io: std.Io, path: []const u8) bool {
    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return false;
    file.close(io);
    return true;
}

fn loadFastaGzip(io: std.Io, gpa: std.mem.Allocator, builder: *genDb.Builder, path: []const u8) !void {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var file_buffer: [128 * 1024]u8 = undefined;
    var file_reader = file.reader(io, &file_buffer);
    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(&file_reader.interface, .gzip, &decompress_buffer);
    try builder.addFasta(gpa, &decompressor.reader);
}

