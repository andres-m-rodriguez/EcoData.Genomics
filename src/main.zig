const std = @import("std");
const EcoData_Genomics = @import("EcoData_Genomics");
const pipeline = EcoData_Genomics.pipeline;

pub fn main(init: std.process.Init) !void {
    var console_buffer: [4096]u8 = undefined;
    var console = std.Io.File.stdout().writer(init.io, &console_buffer);
    const print = &console.interface;

    const db_path = "output.egdb";
    const reads_path = "data/test_reads/mixed_reads.fastq.gz";

    var db_future = try init.io.concurrent(pipeline.buildDatabase, .{ init.io, init.gpa, db_path });
    var reads_future = try init.io.concurrent(pipeline.loadAndTrimReads, .{ init.io, init.gpa, reads_path });

    try print.print("[1/3] Building database...\n", .{});
    try print.print("[2/3] Loading and trimming reads...\n", .{});
    try print.flush();

    var database = try db_future.await(init.io);
    defer database.deinit(init.io, init.gpa);

    const trimmed = try reads_future.await(init.io);
    defer init.gpa.free(trimmed);

    try print.print("       Database: {} k-mers, {} taxons\n", .{ database.kmers.len, database.taxons.len });
    try print.print("       Reads: {} trimmed\n", .{trimmed.len});

    try print.print("[3/3] Classifying...\n", .{});
    try print.flush();

    try pipeline.classifyReads(init.io, init.gpa, print, database, trimmed);
}
