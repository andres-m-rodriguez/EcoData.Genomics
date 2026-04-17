const std = @import("std");
const seqio = @import("../seqio.zig");
const Fastq = seqio.Fastq;
const phred = seqio.phred;
const Threshold = @import("../seqio.zig").phred.Threshold;
const FastqRecord = Fastq.Record;

pub fn trimSlidingWindow(value: []const u8, k: u32, threshold: u8) usize {
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

    return value.len;
}
pub fn validateMean(quality: []const u8, min: u8) bool {
    if (quality.len == 0) return false;
    var sum: u32 = 0;
    for (quality) |q| sum += phred.decode(q);
    const mean = @as(f32, @floatFromInt(sum)) / @as(f32, @floatFromInt(quality.len));
    return mean >= @as(f32, @floatFromInt(min));
}
pub const Options = struct {
    window_size: u32 = 4,
    min_window_quality: u8 = Threshold.q20,
    min_length: u32 = 50,
    min_mean_quality: u8 = Threshold.q20,
};
pub fn trim(quality: []const u8, options: Options) ?usize {
    const cut = trimSlidingWindow(quality, options.window_size, options.min_window_quality);

    if (cut < options.min_length)
        return null;

    if (!validateMean(quality[0..cut], options.min_mean_quality))
        return null;

    return cut;
}

test "can i" {
    const cut = trimSlidingWindow(&.{ '!', '!', '!', 'I', 'I', 'H', 'F', 'D', '!', '!', '!' }, 3, Threshold.q40);

    std.debug.print("{}", .{cut});
}
