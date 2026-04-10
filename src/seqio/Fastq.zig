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

// ============================================================================
// Error Sets
// ============================================================================

pub const Error = error{
    InvalidHeader,
    MissingSequence,
    InvalidSeparator,
    MissingQuality,
    LengthMismatch,
};

pub const ReadError = Error || error{ ReadFailed, StreamTooLong };

// ============================================================================
// Record Type
// ============================================================================

pub const Record = struct {
    header: []const u8,
    sequence: []const u8,
    quality: []const u8,

    pub fn qualityAt(self: Record, i: usize) u8 {
        return phred.decode(self.quality[i]);
    }
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
