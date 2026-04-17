const std = @import("std");
const EcoData_Genomics = @import("EcoData_Genomics");
const seqio = EcoData_Genomics.seqio;
const Fasta = seqio.Fasta;
const kmer = EcoData_Genomics.kmer;
const genDb = EcoData_Genomics.genDb;
pub fn main(init: std.process.Init) !void {
    var console_writer_buffer: [4096]u8 = undefined;
    var console_writer = std.Io.File.stdout().writer(init.io, &console_writer_buffer);

    const data_file_path = "data/reference_genomes/ecoli_k12.fna.gz";
    const output_file_path = "output.egdb";

    const file = try std.Io.Dir.cwd().openFile(init.io, data_file_path, .{});
    defer file.close(init.io);
    var file_reader_buffer: [128 * 1024]u8 = undefined;
    var file_reader = file.reader(init.io, &file_reader_buffer);

    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(&file_reader.interface, .gzip, &decompress_buffer);
    var builder = genDb.Builder.init(kmer.K.kraken2_k, kmer.K.kraken2_l);
    try builder.addFasta(init.gpa, &decompressor.reader);
    defer builder.deinit(init.gpa);
    const output_file = try std.Io.Dir.cwd().createFile(init.io, output_file_path, .{});
    var output_file_buffer: [128 * 1024]u8 = undefined;
    var output_file_writer = output_file.writer(init.io, &output_file_buffer);

    try builder.build(&output_file_writer.interface);
    output_file.close(init.io);

    var database = genDb.Database.init(kmer.K.kraken2_k, kmer.K.kraken2_l);
    defer database.deinit(init.io, init.gpa);
    try database.loadFromFile(init.io, init.gpa, output_file_path);
    try console_writer.interface.print("Database loaded: {} kmers\n", .{database.kmers.len});

    // Verify binary search works by looking up first and last kmers
    if (database.kmers.len > 0) {
        const first_kmer = database.kmers[0];
        const last_kmer = database.kmers[database.kmers.len - 1];

        if (database.getTaxonId(first_kmer)) |taxon| {
            try console_writer.interface.print("First kmer lookup: taxon {}\n", .{taxon});
        } else {
            try console_writer.interface.print("First kmer lookup failed!\n", .{});
        }

        if (database.getTaxonId(last_kmer)) |taxon| {
            try console_writer.interface.print("Last kmer lookup: taxon {}\n", .{taxon});
        } else {
            try console_writer.interface.print("Last kmer lookup failed!\n", .{});
        }

        // Test a non-existent kmer (all 1s, unlikely to exist)
        if (database.getTaxonId(0xFFFFFFFFFFFFFFFF)) |_| {
            try console_writer.interface.print("Unexpected: found non-existent kmer\n", .{});
        } else {
            try console_writer.interface.print("Non-existent kmer correctly returned null\n", .{});
        }
    }

    try console_writer.interface.print("Database verification completed!\n", .{});
    try console_writer.interface.flush();
}
