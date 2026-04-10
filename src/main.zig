const std = @import("std");
const EcoData_Genomics = @import("EcoData_Genomics");
const seqio = EcoData_Genomics.seqio;

pub fn main(init: std.process.Init) !void {
var console_writer_buffer: [4092]u8 = undefined;
    var console_writer = std.Io.File.stdout().writer(init.io, &console_writer_buffer);
    var sample_reader = std.Io.Reader.fixed(fastq_sample);

    while (try seqio.Fastq.next(&sample_reader)) |record| {
        try console_writer.interface.print("Id:{s}\nSequence:{s}\nQuality:{s}", .{
            record.header,
            record.sequence,
            record.quality,
        });

    }

    try console_writer.flush();
}

const fastq_sample =
    \\@SEQ_ID description
    \\GATTTGGGG
    \\+
    \\!''*((((*
;
