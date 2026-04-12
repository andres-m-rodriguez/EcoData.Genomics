const std = @import("std");
const EcoData_Genomics = @import("EcoData_Genomics");
const seqio = EcoData_Genomics.seqio;
const Fastq = seqio.Fastq;
const FastqRecord = Fastq.Record;
const trimmer = EcoData_Genomics.trimmer;
const kmer = EcoData_Genomics.kmer; 

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

    const passed_file = try std.Io.Dir.cwd().createFile(init.io, "passed.csv", .{});
    defer passed_file.close(init.io);
    var passed_writer_buffer: [128 * 1024]u8 = undefined;
    var passed_writer = passed_file.writer(init.io, &passed_writer_buffer);

    const failed_file = try std.Io.Dir.cwd().createFile(init.io, "failed.csv", .{});
    defer failed_file.close(init.io);
    var failed_writer_buffer: [128 * 1024]u8 = undefined;
    var failed_writer = failed_file.writer(init.io, &failed_writer_buffer);

    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(&file_reader.interface, .gzip, &decompress_buffer);

    var passed_queue_buffer: [128]FastqRecord.Fixed = undefined;
    var passed_queue = std.Io.Queue(FastqRecord.Fixed).init(&passed_queue_buffer);
    var failed_queue_buffer: [128]FastqRecord.Fixed = undefined;
    var failed_queue = std.Io.Queue(FastqRecord.Fixed).init(&failed_queue_buffer);

    var parser = try std.Io.concurrent(init.io, parseRecords, .{
        init.io,
        &passed_queue,
        &failed_queue,
        &decompressor.reader,
    });
    var passed_consumer = try std.Io.concurrent(init.io, writeCsv, .{ init.io, &passed_queue, &passed_writer.interface });
    var failed_consumer = try std.Io.concurrent(init.io, writeCsv, .{ init.io, &failed_queue, &failed_writer.interface });

    const passed_counter = try passed_consumer.await(init.io);
    const failed_counter = try failed_consumer.await(init.io);
    _ = try parser.await(init.io);
    const end = std.Io.Clock.Timestamp.now(init.io, .awake);
    const elapsed = start.durationTo(end);

    try console_writer.interface.print("Done: {} passed, {} failed in {}ms\n", .{
        passed_counter,
        failed_counter,
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
        try writer.print("\"{s}\",\"{s}\",{d:.2}\n", .{ record.getHeader(), record.getQuality(), record.meanQuality() });
        counter += 1;
    }
    try writer.flush();

    return counter;
}
fn parseRecords(io: std.Io, passed_queue: *std.Io.Queue(FastqRecord.Fixed), failed_queue: *std.Io.Queue(FastqRecord.Fixed), reader: *std.Io.Reader) !void {
    while (try seqio.Fastq.next(reader)) |record| {
        if (trimmer.trim(record, .{
            .min_window_quality = phred.Threshold.q30,
            .min_mean_quality = phred.Threshold.q30,
        })) |valid_record| {
            try passed_queue.putOne(io, FastqRecord.Fixed.fromRecord(valid_record));
        } else {
            try failed_queue.putOne(io, FastqRecord.Fixed.fromRecord(record));
        }
    }

    passed_queue.close(io);
    failed_queue.close(io);
}
