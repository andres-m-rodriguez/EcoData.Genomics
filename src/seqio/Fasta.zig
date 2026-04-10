//! FASTA format parser.
//!
//! FASTA files contain sequences without quality scores.
//! Each record consists of:
//!   1. Header line starting with '>' followed by identifier and optional description
//!   2. One or more sequence lines containing A, T, C, G, N characters
//!
//! Sequence lines are typically wrapped at 60 or 80 characters but may vary.
//! This parser concatenates multi-line sequences into a single sequence field.

const std = @import("std");
const Io = std.Io;

const Fasta = @This();

// ============================================================================
// Error Sets
// ============================================================================

pub const Error = error{
    /// Header line does not start with '>'.
    InvalidHeader,
    /// Sequence is empty (no sequence lines after header).
    EmptySequence,
    /// Encountered invalid character in sequence.
    InvalidSequenceChar,
};

pub const ReadError = Error || Io.Reader.Error;
pub const AllocError = Error || std.mem.Allocator.Error;

// ============================================================================
// Record Type
// ============================================================================

pub const Record = struct {
    identifier: []const u8,
    description: ?[]const u8,
    sequence: []const u8,

    /// Returns the GC content as a ratio (0.0 to 1.0).
    pub fn gcContent(self: Record) f32 {
        _ = self;
        @panic("not implemented");
    }

    /// Returns the length of the sequence.
    pub fn len(self: Record) usize {
        return self.sequence.len;
    }
};

// ============================================================================
// Parser State
// ============================================================================

pub const State = enum {
    /// Expecting header line starting with '>'.
    header,
    /// Reading sequence lines until next header or EOF.
    sequence,
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
allocator: std.mem.Allocator,

// ============================================================================
// Initialization
// ============================================================================

pub fn init(allocator: std.mem.Allocator) Fasta {
    return .{
        .allocator = allocator,
    };
}

pub fn initWithDiagnostics(allocator: std.mem.Allocator, diagnostics: *Diagnostics) Fasta {
    return .{
        .allocator = allocator,
        .diagnostics = diagnostics,
    };
}

// ============================================================================
// Core API
// ============================================================================

/// Parse next record from reader.
/// Returns null at end of input, error on malformed input.
/// Caller owns returned memory and must free with `freeRecord`.
pub fn next(self: *Fasta, reader: *Io.Reader) (AllocError || Io.Reader.Error)!?Record {
    _ = self;
    _ = reader;
    @panic("not implemented");
}

/// Free memory allocated for a record.
pub fn freeRecord(self: *Fasta, record: Record) void {
    _ = self;
    _ = record;
    @panic("not implemented");
}

/// Skip the next record without allocating or returning it.
pub fn skip(self: *Fasta, reader: *Io.Reader) ReadError!bool {
    _ = self;
    _ = reader;
    @panic("not implemented");
}

/// Reset parser state for reuse with a new input.
pub fn reset(self: *Fasta) void {
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
pub fn iterator(allocator: std.mem.Allocator, reader: *Io.Reader) Iterator {
    return Iterator.init(allocator, reader);
}

pub const Iterator = struct {
    reader: *Io.Reader,
    parser: Fasta,

    pub fn init(allocator: std.mem.Allocator, reader: *Io.Reader) Iterator {
        return .{
            .reader = reader,
            .parser = Fasta.init(allocator),
        };
    }

    pub fn next(self: *Iterator) (AllocError || Io.Reader.Error)!?Record {
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

/// Check if a character is valid in a FASTA sequence line.
/// Includes DNA bases plus common gap/mask characters.
pub fn isValidSequenceChar(char: u8) bool {
    return switch (char) {
        'A', 'T', 'C', 'G', 'N', 'a', 't', 'c', 'g', 'n' => true,
        '-', '.' => true, // gap characters
        else => false,
    };
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
    try std.testing.expect(!isValidBase('>'));
}
