const std = @import("std");
const EcoData_Genomics = @import("EcoData_Genomics");
const seqio = EcoData_Genomics.seqio;
const Fasta = seqio.Fasta;
const kmer = EcoData_Genomics.kmer;
const genDb = EcoData_Genomics.genDb;
pub fn main(init: std.process.Init) !void {
    var console_writer_buffer: [4096]u8 = undefined;
    var console_writer = std.Io.File.stdout().writer(init.io, &console_writer_buffer);
    const print = &console_writer.interface;

    const fasta_file_path = "data/reference_genomes/ecoli_k12.fna.gz";
    const output_file_path = "output.egdb";

    // Benchmark: Build database
    var start = std.Io.Clock.awake.now(init.io);
    try buildDatabase(init.io, init.gpa, fasta_file_path, output_file_path);
    var end = std.Io.Clock.awake.now(init.io);
    try print.print("Build time: {}ms\n", .{start.durationTo(end).toMilliseconds()});

    // Benchmark: Load database
    start = std.Io.Clock.awake.now(init.io);
    var database = genDb.Database.init(kmer.K.kraken2_k, kmer.K.kraken2_l);
    defer database.deinit(init.io, init.gpa);
    try database.loadFromFile(init.io, init.gpa, output_file_path);
    end = std.Io.Clock.awake.now(init.io);
    try print.print("Load time: {}ms\n", .{start.durationTo(end).toMilliseconds()});
    try print.print("Database loaded: {} kmers, {} taxons\n", .{ database.kmers.len, database.taxons.len });

    // Benchmark: Lookups
    if (database.kmers.len > 0) {
        const num_lookups: usize = 100_000;
        start = std.Io.Clock.awake.now(init.io);
        for (0..num_lookups) |i| {
            const kmer_idx = i % database.kmers.len;
            _ = database.getTaxonId(database.kmers[kmer_idx]);
        }
        end = std.Io.Clock.awake.now(init.io);
        const duration_ns = start.durationTo(end).toNanoseconds();
        const ns_per_lookup = @divTrunc(duration_ns, num_lookups);
        try print.print("Lookups: {} in {}ms ({}ns/lookup)\n", .{
            num_lookups,
            start.durationTo(end).toMilliseconds(),
            ns_per_lookup,
        });
    }

    try console_writer.interface.flush();
}

pub fn buildDatabase(io: std.Io, allocator: std.mem.Allocator, input_file_path: []const u8, output_file_path: []const u8) !void {
    const input_file = try std.Io.Dir.cwd().openFile(io, input_file_path, .{});
    defer input_file.close(io);
    var input_file_r_buffer: [128 * 1024]u8 = undefined;
    var input_file_r = input_file.reader(io, &input_file_r_buffer);

    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(&input_file_r.interface, .gzip, &decompress_buffer);

    var builder = genDb.Builder.init(kmer.K.kraken2_k, kmer.K.kraken2_l);
    try builder.look_up.map.ensureTotalCapacity(allocator, 2_000_000);
    try builder.addFasta(allocator, &decompressor.reader);
    defer builder.deinit(allocator);
    const output_file = try std.Io.Dir.cwd().createFile(io, output_file_path, .{});
    var output_file_r_buffer: [128 * 1024]u8 = undefined;
    var output_file_w = output_file.writer(io, &output_file_r_buffer);
    defer output_file.close(io);

    try builder.build(&output_file_w.interface);
}
