const std = @import("std");
const Io = std.Io;

const Fasta = @This();

pub const Error = error{
    InvalidHeader,
    EmptySequence,
    InvalidSequenceChar,
};

pub const ReadError = Error || Io.Reader.Error;
pub const AllocError = Error || std.mem.Allocator.Error;

pub const Record = struct {
    header: []const u8 = "",
    sequences: Sequence = .{},

    pub fn deinit(self: *Record, allocator: std.mem.Allocator) void {
        allocator.free(self.header);
        self.sequences.deinit(allocator);
    }
};
pub const Sequence = struct {
    data: std.ArrayList(u8) = .empty,
    line_ends: std.ArrayList(usize) = .empty,
    pub fn deinit(self: *Sequence, allocator: std.mem.Allocator) void {
        self.data.deinit(allocator);
        self.line_ends.deinit(allocator);
    }
    pub fn appendLine(self: *Sequence, allocator: std.mem.Allocator, line: []const u8) !void {
        try self.data.appendSlice(allocator, line);
        try self.line_ends.append(allocator, self.data.items.len);
    }

    pub fn getLine(self: *const Sequence, i: usize) []const u8 {
        const start = if (i == 0) 0 else self.line_ends.items[i - 1];
        const end = self.line_ends.items[i];
        return self.data.items[start..end];
    }
    pub fn iterator(self: *const Sequence) Iterator {
        return .{ .sequence = self };
    }

    pub const Iterator = struct {
        sequence: *const Sequence,
        index: usize = 0,

        pub fn next(self: *Iterator) ?[]const u8 {
            if (self.index >= self.sequence.line_ends.items.len) return null;
            const line = self.sequence.getLine(self.index);
            self.index += 1;
            return line;
        }

        pub fn reset(self: *Iterator) void {
            self.index = 0;
        }
    };
};

pub fn next(allocator: std.mem.Allocator, reader: *std.Io.Reader) !?Record {
    var record = Record{};
    errdefer record.deinit(allocator);
    const identifier_line = try reader.takeDelimiter('\n') orelse return null;
    if (identifier_line.len == 0 or identifier_line[0] != '>')
        return Error.InvalidHeader;
    const identifier = try allocator.dupe(u8, identifier_line);
    record.header = identifier;
    while (true) {
        const next_byte = reader.peekByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        if (next_byte == '>') break;

        const current_sequence = try reader.takeDelimiter('\n') orelse break;
        try record.sequences.appendLine(allocator, current_sequence);
    }

    return record;
}
