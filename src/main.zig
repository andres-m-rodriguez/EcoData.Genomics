const std = @import("std");
const EcoData_Genomics = @import("EcoData_Genomics");
const pipeline = EcoData_Genomics.pipeline;

const Config = struct {
    references: []const []const u8 = &.{
        "data/reference_genomes/ecoli_k12.fna.gz",
        "data/reference_genomes/legionella_pneumophila.fna.gz",
        "data/reference_genomes/pseudomonas_aeruginosa.fna.gz",
        "data/reference_genomes/salmonella_enterica.fna.gz",
        "data/reference_genomes/vibrio_cholerae.fna.gz",
    },
    database_path: []const u8 = "output.egdb",
    reads_path: []const u8 = "data/test_reads/mixed_reads.fastq.gz",
};

pub fn main(init: std.process.Init) !void {
    var console_buffer: [4096]u8 = undefined;
    var console = std.Io.File.stdout().writer(init.io, &console_buffer);
    const start = std.Io.Clock.awake.now(init.io);

    defer {
        const end = std.Io.Clock.awake.now(init.io);
        const ms = start.durationTo(end).toMilliseconds();
        console.interface.print("\nCompleted in {d:.2}s\n", .{@as(f64, @floatFromInt(ms)) / 1000.0}) catch {};
        console.interface.flush() catch {};
    }

    const config = Config{};
    var p = pipeline.Pipeline.init(init.io, init.gpa, &console.interface, 5);

    var database = try pipeline.buildDatabase(&p, config.references, config.database_path);
    defer database.deinit(init.io, init.gpa);

    const reads = try pipeline.loadReads(&p, config.reads_path);
    defer init.gpa.free(reads);

    const trimmed = try pipeline.trimReads(&p, reads);
    defer init.gpa.free(trimmed);

    try pipeline.classifyReads(&p, database, trimmed);
}
