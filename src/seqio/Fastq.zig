//! FASTQ format parser.
//!
//! FASTQ files contain sequences with per-base quality scores encoded as ASCII.
//! Each record consists of four lines:
//!   1. Header line starting with '@' followed by identifier and optional description
//!   2. Sequence line containing A, T, C, G, N characters
//!   3. Separator line starting with '+' (may repeat identifier)
//!   4. Quality line with ASCII-encoded Phred scores (same length as sequence)

const std = @import("std");
const Io = std.Io;
const phred = @import("phred.zig");


pub const Error = error{
    InvalidHeader,
    MissingSequence,
    InvalidSeparator,
    MissingQuality,
    LengthMismatch,
};

pub const ReadError = Error || error{ ReadFailed, StreamTooLong };

pub const Record = struct {
    header: []const u8,
    sequence: []const u8,
    quality: []const u8,

    pub fn qualityAt(self: Record, i: usize) u8 {
        return phred.decode(self.quality[i]);
    }
    pub fn meanQuality(self: Record) f32 {
        return phred.mean(self.quality);
    }
    pub fn meetsQualityThreshold(self: Record, min_phred: u8, min_fraction: f32) bool {
        const passing = phred.countAboveThreshold(self.quality, min_phred);
        return @as(f32, @floatFromInt(passing)) / @as(f32, @floatFromInt(self.quality.len)) >= min_fraction;
    }
      pub const Fixed = struct {
          header: [256]u8,
          header_len: u16,
          sequence: [10000]u8,
          seq_len: u16,
          quality: [10000]u8,
          qual_len: u16,

          pub fn getHeader(self: *const Fixed) []const u8 {
              return self.header[0..self.header_len];
          }
          pub fn getSequence(self: *const Fixed) []const u8 {
              return self.sequence[0..self.seq_len];
          }
          pub fn getQuality(self: *const Fixed) []const u8 {
              return self.quality[0..self.qual_len];
          }
      };
};

/// Parse next record from reader.
/// Returns null at end of input, error on malformed input.
pub fn next(reader: *Io.Reader) ReadError!?Record {
    const header = try reader.takeDelimiter('\n') orelse return null;
    if (header.len == 0 or header[0] != '@') return Error.InvalidHeader;

    const sequence = try reader.takeDelimiter('\n') orelse return Error.MissingSequence;
    const separator = try reader.takeDelimiter('\n') orelse return Error.InvalidSeparator;
    if (separator.len == 0 or separator[0] != '+') return Error.InvalidSeparator;

    const quality = try reader.takeDelimiter('\n') orelse return Error.MissingQuality;
    if (quality.len != sequence.len) return Error.LengthMismatch;

    return Record{
        .header = header,
        .sequence = sequence,
        .quality = quality,
    };
}

// ============================================================================
// Validation
// ============================================================================

pub fn isValid(record: Record) bool {
    for (record.sequence) |char| {
        if (!isValidBase(char)) return false;
    }
    for (record.quality) |char| {
        if (!isValidQuality(char)) return false;
    }
    return true;
}
pub fn isValidBase(char: u8) bool {
    return switch (char) {
        'A', 'T', 'C', 'G', 'N', 'a', 't', 'c', 'g', 'n' => true,
        else => false,
    };
}

pub fn isValidQuality(char: u8) bool {
    return char >= 33 and char <= 126;
}

// ============================================================================
// Tests
// ============================================================================

test "isValidBase" {
    try std.testing.expect(isValidBase('A'));
    try std.testing.expect(isValidBase('T'));
    try std.testing.expect(isValidBase('C'));
    try std.testing.expect(isValidBase('G'));
    try std.testing.expect(isValidBase('N'));
    try std.testing.expect(!isValidBase('X'));
    try std.testing.expect(!isValidBase('@'));
}
