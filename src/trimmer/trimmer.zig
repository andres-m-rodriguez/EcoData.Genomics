const std = @import("std");
const seqio = @import("../seqio.zig");
const Fastq = seqio.Fastq;
const phred = seqio.phred;
const Threshold = @import("../seqio.zig").phred.Threshold;
const FastqRecord = Fastq.Record;

pub fn trimSlidingWindow(value: []const u8, k: u32, threshold: u8) u32 {
    var left_index: u32 = 0;
    var right_index = k;
    var sum: i32 = 0;
    for (value[0..k]) |v| sum += phred.decode(v);
    if (@divFloor(sum, @as(i32, @intCast(k))) < threshold)
        return 0;

    while (right_index < value.len) {
        const left_value = @as(i32, phred.decode(value[left_index]));
        const right_value = @as(i32, phred.decode(value[right_index]));
        sum += right_value - left_value;
        const avg = @divFloor(sum, @as(i32, @intCast(k)));
        if (avg < threshold)
            return left_index;

        left_index += 1;
        right_index += 1;
    }

    return @intCast(value.len);
}
pub fn validateMean(record: FastqRecord, min: u8) bool {
    return record.meanQuality() >= @as(f32, @floatFromInt(min));
}
pub const Options = struct {
    window_size: u32 = 4,
    min_window_quality: u8 = Threshold.q20,
    min_length: u32 = 50,
    min_mean_quality: u8 = Threshold.q20,
};
pub fn trim(record: FastqRecord, options: Options) ?FastqRecord {
    const cut = trimSlidingWindow(record.quality, options.window_size, options.min_window_quality);
    const trimmed = FastqRecord{
        .header = record.header,
        .sequence = record.sequence[0..cut],
        .quality = record.quality[0..cut],
    };
    if (trimmed.quality.len < options.min_length)
        return null;

    const is_valid = validateMean(trimmed, options.min_mean_quality);
    if (!is_valid)
        return null;

    return trimmed;
}

test "can i" {
    const cut = trimSlidingWindow(&.{ '!', '!', '!', 'I', 'I', 'H', 'F', 'D', '!', '!', '!' }, 3, Threshold.q40);

    std.debug.print("{}", .{cut});
}
