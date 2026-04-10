//! FASTQ format parser.
//!
//! FASTQ files contain sequences with per-base quality scores encoded as ASCII.
//! Each record consists of four lines:
//!   1. Header line starting with '@' followed by identifier and optional description
//!   2. Sequence line containing A, T, C, G, N characters
//!   3. Separator line starting with '+' (may repeat identifier)
//!   4. Quality line with ASCII-encoded Phred scores (same length as sequence)
//!
//! This parser supports streaming reads for processing large sequencing files.

const std = @import("std");
const Io = std.Io;
const phred = @import("phred.zig");

const Fastq = @This();

// ============================================================================
// Error Sets
// ============================================================================

pub const Error = error{
    /// Header line does not start with '@'.
    InvalidHeader,
    /// Sequence line is missing or empty.
    MissingSequence,
    /// Separator line does not start with '+'.
    InvalidSeparator,
    /// Quality line is missing.
    MissingQuality,
    /// Quality line length does not match sequence length.
    LengthMismatch,
    /// Encountered invalid character in sequence.
    InvalidSequenceChar,
    /// Encountered invalid character in quality string.
    InvalidQualityChar,
};

pub const ReadError = Error || Io.Reader.Error;

// ============================================================================
// Record Type
// ============================================================================

pub const Record = struct {
    /// Sequence identifier (text after '@' before first space).
    identifier: []const u8,
    /// Optional description (text after first space in header).
    description: ?[]const u8,
    /// DNA sequence (A, T, C, G, N characters).
    sequence: []const u8,
    /// Quality scores as raw ASCII string.
    quality: []const u8,

    /// Returns Phred quality score at position i.
    pub fn qualityAt(self: Record, i: usize) u8 {
        return phred.decode(self.quality[i]);
    }

    /// Returns the average quality score across all bases.
    pub fn meanQuality(self: Record) f32 {
        _ = self;
        @panic("not implemented");
    }

    /// Returns true if all quality scores meet the threshold.
    pub fn meetsQualityThreshold(self: Record, min_phred: u8) bool {
        _ = self;
        _ = min_phred;
        @panic("not implemented");
    }
};

// ============================================================================
// Parser State
// ============================================================================

pub const State = enum {
    /// Expecting header line starting with '@'.
    header,
    /// Expecting sequence line.
    sequence,
    /// Expecting separator line starting with '+'.
    separator,
    /// Expecting quality line.
    quality,
};

pub const Diagnostics = struct {
    /// Current line number in input (1-indexed).
    line_number: u64 = 1,
    /// Number of complete records parsed.
    records_parsed: u64 = 0,
    /// Total bytes processed.
    bytes_processed: u64 = 0,
};

// ============================================================================
// Parser Fields
// ============================================================================

state: State = .header,
diagnostics: ?*Diagnostics = null,

// ============================================================================
// Initialization
// ============================================================================

pub fn init() Fastq {
    return .{};
}

pub fn initWithDiagnostics(diagnostics: *Diagnostics) Fastq {
    return .{
        .diagnostics = diagnostics,
    };
}

// ============================================================================
// Core API
// ============================================================================

/// Parse next record from reader.
/// Returns null at end of input, error on malformed input.
pub fn next(self: *Fastq, reader: *Io.Reader) ReadError!?Record {
    _ = self;
    _ = reader;
    @panic("not implemented");
}

/// Skip the next record without allocating or returning it.
pub fn skip(self: *Fastq, reader: *Io.Reader) ReadError!bool {
    _ = self;
    _ = reader;
    @panic("not implemented");
}

/// Reset parser state for reuse with a new input.
pub fn reset(self: *Fastq) void {
    self.state = .header;
    if (self.diagnostics) |d| {
        d.line_number = 1;
        d.records_parsed = 0;
        d.bytes_processed = 0;
    }
}

// ============================================================================
// Convenience Functions
// ============================================================================

/// Iterator interface for use with for loops.
pub fn iterator(reader: *Io.Reader) Iterator {
    return Iterator.init(reader);
}

pub const Iterator = struct {
    reader: *Io.Reader,
    parser: Fastq,

    pub fn init(reader: *Io.Reader) Iterator {
        return .{
            .reader = reader,
            .parser = Fastq.init(),
        };
    }

    pub fn next(self: *Iterator) ReadError!?Record {
        return self.parser.next(self.reader);
    }
};

// ============================================================================
// Validation
// ============================================================================

/// Check if a character is a valid DNA base (A, T, C, G, N).
pub fn isValidBase(char: u8) bool {
    return switch (char) {
        'A', 'T', 'C', 'G', 'N', 'a', 't', 'c', 'g', 'n' => true,
        else => false,
    };
}

/// Check if a character is a valid quality score character.
pub fn isValidQuality(char: u8) bool {
    // Phred+33 encoding: ASCII 33 ('!') to 126 ('~')
    return char >= 33 and char <= 126;
}

// ============================================================================
// Tests
// ============================================================================

test "Record.qualityAt" {
    // TODO: add tests
}

test "isValidBase" {
    try std.testing.expect(isValidBase('A'));
    try std.testing.expect(isValidBase('T'));
    try std.testing.expect(isValidBase('C'));
    try std.testing.expect(isValidBase('G'));
    try std.testing.expect(isValidBase('N'));
    try std.testing.expect(!isValidBase('X'));
    try std.testing.expect(!isValidBase('@'));
}
