const std = @import("std");
const EcoData_Genomics = @import("EcoData_Genomics");
const seqio = EcoData_Genomics.seqio;
const Fastq = seqio.Fastq;
const FastqRecord = Fastq.Record;
const phred = seqio.phred;

pub fn main(init: std.process.Init) !void {
    const start = std.Io.Clock.Timestamp.now(init.io, .awake);

    var console_writer_buffer: [4096]u8 = undefined;
    var console_writer = std.Io.File.stdout().writer(init.io, &console_writer_buffer);

    const data_file_path = "C:/Users/Overlord/Downloads/SRR36547199.fastq.gz";
    const file = try std.Io.Dir.cwd().openFile(init.io, data_file_path, .{});
    defer file.close(init.io);

    var file_reader_buffer: [128 * 1024]u8 = undefined;
    var file_reader = file.reader(init.io, &file_reader_buffer);

    const output_file = try std.Io.Dir.cwd().createFile(init.io, "output.csv", .{});
    defer output_file.close(init.io);

    var file_writer_buffer: [400 * 1024]u8 = undefined;
    var file_writer = output_file.writer(init.io, &file_writer_buffer);

    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(&file_reader.interface, .gzip, &decompress_buffer);

    var queue_buffer: [128]FastqRecord.Fixed = undefined;
    var queue = std.Io.Queue(FastqRecord.Fixed).init(&queue_buffer);

    var parser = try std.Io.concurrent(init.io, parseRecords, .{
        init.io,
        &queue,
        &decompressor.reader,
    });
    const counter = try writeCsv(init.io, &queue, &file_writer.interface);

    _ = try parser.await(init.io);
    const end = std.Io.Clock.Timestamp.now(init.io, .awake);
    const elapsed = start.durationTo(end);
    try console_writer.interface.print("Done: {} records in {}ms\n", .{
        counter,
        elapsed.raw.toMilliseconds(),
    });
    try console_writer.flush();
}

fn writeCsv(io: std.Io, queue: *std.Io.Queue(FastqRecord.Fixed), writer: *std.Io.Writer) !u64 {
    var counter: u64 = 0;
    while (true) {
        const record = queue.getOne(io) catch |err| switch (err) {
            error.Closed => break,
            else => return err
        };
        try writer.print("\"{s}\",{d:.2}\n", .{ record.getHeader(), record.meanQuality() });
        counter += 1;
    }
    try writer.flush();

    return counter;
}
fn parseRecords(io: std.Io, queue: *std.Io.Queue(FastqRecord.Fixed), reader: *std.Io.Reader) !void {
    while (try seqio.Fastq.next(reader)) |record| {
        try queue.putOne(io, FastqRecord.Fixed.fromRecord(record));
    }

    queue.close(io);
}
