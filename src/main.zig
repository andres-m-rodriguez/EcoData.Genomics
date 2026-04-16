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

    // Decompress gzip
    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(&file_reader.interface, .gzip, &decompress_buffer);
    var builder = genDb.Builder.init(kmer.K.kraken2);
    try builder.addFasta(init.gpa, &decompressor.reader, 1);
    defer builder.deinit(init.gpa);
    {
        const output_file = try std.Io.Dir.cwd().createFile(init.io, output_file_path, .{});
        defer output_file.close(init.io);
        var output_file_writer_buffer: [128 * 1024]u8 = undefined;
        var output_file_writer = output_file.writer(init.io, &output_file_writer_buffer);

        _ = try builder.build(.{
            .writer = &output_file_writer.interface,
            .transfer_index = false,
            .transfer_organisms = false,
        });
    }

    var database = try builder.build(.{
        .writer = null,
        .transfer_index = false,
        .transfer_organisms = true,
    }) orelse unreachable;
    defer database.deinit(init.gpa);
    {
        const output_file = try std.Io.Dir.cwd().openFile(init.io, output_file_path, .{});
        defer output_file.close(init.io);
        var output_file_reader_buffer: [128 * 1024]u8 = undefined;
        var output_file_reader = output_file.reader(init.io, &output_file_reader_buffer);

        try database.loadIndex(init.gpa, &output_file_reader.interface);
    }
    try console_writer.interface.print("Database generation completed!", .{});
    try console_writer.interface.flush();
}
