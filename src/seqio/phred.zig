const std = @import("std");

// ============================================================================
// Encoding Constants
// ============================================================================

/// ASCII offset for Phred+33 encoding 
pub const phred33_offset: u8 = 33;

/// Minimum valid ASCII character in Phred+33 encoding.
pub const min_char: u8 = '!'; // ASCII 33, Q=0

/// Maximum valid ASCII character in Phred+33 encoding.
pub const max_char: u8 = '~'; // ASCII 126, Q=93

// ============================================================================
// Quality Thresholds
// ============================================================================

/// Common quality score thresholds.
pub const Threshold = struct {
    pub const q10: u8 = 10; // 90% accuracy
    pub const q20: u8 = 20; // 99% accuracy
    pub const q30: u8 = 30; // 99.9% accuracy
    pub const q40: u8 = 40; // 99.99% accuracy
};

// ============================================================================
// Encoding/Decoding
// ============================================================================

/// Decode ASCII character to Phred score (Phred+33).
pub fn decode(char: u8) u8 {
    return char -| phred33_offset;
}

/// Encode Phred score to ASCII character (Phred+33).
pub fn encode(score: u8) u8 {
    return score +| phred33_offset;
}

// ============================================================================
// Probability Conversion
// ============================================================================

/// Convert Phred score to error probability.
pub fn toErrorProbability(score: u8) f64 {
    return std.math.pow(f64, 10.0, -@as(f64, @floatFromInt(score)) / 10.0);
}

/// Convert error probability to Phred score.
/// P = 10^(-Q/10) => Q = -10 * log10(P)
pub fn fromErrorProbability(probability: f64) u8 {
    return @intFromFloat(-10.0 * std.math.log10(probability));
}

/// Convert Phred score to accuracy (1 - error probability).
pub fn toAccuracy(score: u8) f64 {
    return 1.0 - toErrorProbability(score);
}

// ============================================================================
// Statistics
// ============================================================================

/// Calculate mean Phred score from quality string.
pub fn mean(quality: []const u8) f32 {
    var sum: u32 = 0;
    for (quality) |char| sum += decode(char);
    return @as(f32, @floatFromInt(sum)) / @as(f32, @floatFromInt(quality.len));
}

/// Calculate median Phred score from quality string.
pub fn median(quality: []const u8) u8 {
    var scores: [128]u8 = undefined;
    for (quality, 0..) |char, i| scores[i] = decode(char);
    const slice = scores[0..quality.len];
    std.mem.sort(u8, slice, {}, std.sort.asc(u8));
    return if (slice.len % 2 == 0)
        (slice[slice.len / 2 - 1] + slice[slice.len / 2]) / 2
    else
        slice[slice.len / 2];
}

/// Count bases meeting minimum quality threshold.
pub fn countAboveThreshold(quality: []const u8, min_score: u8) usize {
    var count: usize = 0;
    for (quality) |char| {
        if (decode(char) >= min_score) count += 1;
    }
    return count;
}

/// Find positions where quality drops below threshold.
pub fn findLowQualityPositions(
    allocator: std.mem.Allocator,
    quality: []const u8,
    min_score: u8,
) std.mem.Allocator.Error![]usize {
    var positions = std.ArrayList(usize).init(allocator);
    for (quality, 0..) |char, i| {
        if (decode(char) < min_score) try positions.append(i);
    }
    return positions.toOwnedSlice();
}

// ============================================================================
// Validation
// ============================================================================

/// Check if character is valid Phred+33 quality character.
pub fn isValid(char: u8) bool {
    return char >= min_char and char <= max_char;
}

/// Validate entire quality string.
pub fn validateString(quality: []const u8) bool {
    for (quality) |char| {
        if (!isValid(char)) return false;
    }
    return true;
}

// ============================================================================
// Encoding Detection
// ============================================================================

pub const Encoding = enum {
    phred33,
    phred64,
    unknown,
};

/// Attempt to detect encoding from quality string.
/// Returns .phred33 if any char < 64, .phred64 if all chars >= 64, .unknown otherwise.
pub fn detectEncoding(quality: []const u8) Encoding {
    for (quality) |char| {
        if (char < 64) return .phred33;
    }
    if (quality.len == 0) return .unknown;
    return .phred64;
}

// ============================================================================
// Tests
// ============================================================================

test "decode" {
    try std.testing.expectEqual(@as(u8, 0), decode('!'));
    try std.testing.expectEqual(@as(u8, 30), decode('?'));
    try std.testing.expectEqual(@as(u8, 40), decode('I'));
}

test "encode" {
    try std.testing.expectEqual(@as(u8, '!'), encode(0));
    try std.testing.expectEqual(@as(u8, '?'), encode(30));
    try std.testing.expectEqual(@as(u8, 'I'), encode(40));
}

test "isValid" {
    try std.testing.expect(isValid('!'));
    try std.testing.expect(isValid('I'));
    try std.testing.expect(isValid('~'));
    try std.testing.expect(!isValid(' '));
    try std.testing.expect(!isValid(0));
}
