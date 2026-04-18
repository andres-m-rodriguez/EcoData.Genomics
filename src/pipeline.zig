const std = @import("std");
const EcoData_Genomics = @import("root.zig");
const seqio = EcoData_Genomics.seqio;
const kmer = EcoData_Genomics.kmer;
const genDb = EcoData_Genomics.genDb;
const classifier = EcoData_Genomics.classifier;
const trimmer = @import("trimmer.zig");
const benchmark_refs = @import("benchmark_refs.zig");

pub const TrimmedRead = trimmer.TrimmedRead;

fn getNumChunks() usize {
    const cpu_count = std.Thread.getCpuCount() catch 4;
    const total_files = benchmark_refs.gzip.len + benchmark_refs.raw.len;
    return @min(cpu_count, total_files);
}

pub fn buildDatabase(io: std.Io, gpa: std.mem.Allocator, output_path: []const u8) !genDb.Database {
    const cached = dbExists(io, output_path);

    if (!cached) {
        const num_chunks = getNumChunks();
        const builders = try gpa.alloc(genDb.Builder, num_chunks);
        defer gpa.free(builders);

        for (builders) |*b| {
            b.* = genDb.Builder.init(kmer.K.kraken2_k, kmer.K.kraken2_l);
            try b.look_up.map.ensureTotalCapacity(gpa, 100_000_000 / num_chunks);
        }

        var total_errors: usize = 0;
        for (builders, 0..) |*b, i| {
            total_errors += buildChunk(io, gpa, b, i, num_chunks);
        }

        var final = genDb.Builder.init(kmer.K.kraken2_k, kmer.K.kraken2_l);
        defer final.deinit(gpa);
        try final.look_up.map.ensureTotalCapacity(gpa, 500_000_000);

        for (builders) |*b| {
            try final.merge(gpa, b);
            b.deinit(gpa);
        }

        if (total_errors > 0) {
            std.debug.print("Warning: {d} files failed to load\n", .{total_errors});
        }

        const output_file = try std.Io.Dir.cwd().createFile(io, output_path, .{});
        defer output_file.close(io);
        var output_buffer: [128 * 1024]u8 = undefined;
        var output_writer = output_file.writer(io, &output_buffer);
        try final.build(&output_writer.interface);
    }

    var database = genDb.Database.init(kmer.K.kraken2_k, kmer.K.kraken2_l);
    try database.loadFromFile(io, gpa, output_path);
    return database;
}

fn buildChunk(io: std.Io, gpa: std.mem.Allocator, builder: *genDb.Builder, chunk_idx: usize, num_chunks: usize) usize {
    var error_count: usize = 0;

    for (benchmark_refs.gzip, 0..) |path, idx| {
        if (idx % num_chunks != chunk_idx) continue;
        loadFastaGzip(io, gpa, builder, path) catch |err| {
            std.debug.print("Error loading {s}: {}\n", .{ path, err });
            error_count += 1;
            continue;
        };
    }
    for (benchmark_refs.raw, 0..) |path, idx| {
        if (idx % num_chunks != chunk_idx) continue;
        loadFastaRaw(io, gpa, builder, path) catch |err| {
            std.debug.print("Error loading {s}: {}\n", .{ path, err });
            error_count += 1;
            continue;
        };
    }

    return error_count;
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

fn loadFastaRaw(io: std.Io, gpa: std.mem.Allocator, builder: *genDb.Builder, path: []const u8) !void {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var file_buffer: [128 * 1024]u8 = undefined;
    var file_reader = file.reader(io, &file_buffer);
    try builder.addFasta(gpa, &file_reader.interface);
}
