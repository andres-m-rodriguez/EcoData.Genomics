const std = @import("std");

pub const AllocWhen = enum { alloc_if_needed, alloc_always };

pub const Record = union(enum) {
    borrowed: Borrowed,
    allocated: Allocated,

    pub const Borrowed = struct {
        header: []const u8,
        sequence: []const u8,
        quality: []const u8,
    };

    pub const Allocated = struct {
        header: []u8,
        sequence: []u8,
        quality: []u8,
    };

    pub fn deinit(self: Record, allocator: std.mem.Allocator) void {
        switch (self) {
            .borrowed => {},
            .allocated => |a| {
                allocator.free(a.header);
                allocator.free(a.sequence);
                allocator.free(a.quality);
            },
        }
    }

    pub fn toOwned(self: Record, allocator: std.mem.Allocator) !Record {
        return .{ .allocated = .{
            .header = try allocator.dupe(u8, self.header()),
            .sequence = try allocator.dupe(u8, self.sequence()),
            .quality = try allocator.dupe(u8, self.quality()),
        } };
    }

    pub fn header(self: Record) []const u8 {
        return switch (self) {
            .borrowed => |b| b.header,
            .allocated => |a| a.header,
        };
    }

    pub fn sequence(self: Record) []const u8 {
        return switch (self) {
            .borrowed => |b| b.sequence,
            .allocated => |a| a.sequence,
        };
    }

    pub fn quality(self: Record) []const u8 {
        return switch (self) {
            .borrowed => |b| b.quality,
            .allocated => |a| a.quality,
        };
    }
};

pub fn next(reader: *std.Io.Reader, allocator: std.mem.Allocator, when: AllocWhen) !?Record {
    const header = try reader.takeDelimiter('\n') orelse return null;
    if (header.len == 0 or header[0] != '@') return error.InvalidHeader;

    const sequence = try reader.takeDelimiter('\n') orelse return error.MissingSequence;

    const separator = try reader.takeDelimiter('\n') orelse return error.InvalidSeparator;
    if (separator.len == 0 or separator[0] != '+') return error.InvalidSeparator;

    const quality = try reader.takeDelimiter('\n') orelse return error.MissingQuality;
    if (quality.len != sequence.len) return error.LengthMismatch;

    const all_valid = when == .alloc_if_needed and
        sliceInBuffer(reader, header) and
        sliceInBuffer(reader, sequence) and
        sliceInBuffer(reader, quality);

    if (all_valid) {
        return Record{ .borrowed = .{
            .header = header,
            .sequence = sequence,
            .quality = quality,
        } };
    }

    return Record{ .allocated = .{
        .header = try allocator.dupe(u8, header),
        .sequence = try allocator.dupe(u8, sequence),
        .quality = try allocator.dupe(u8, quality),
    } };
}

fn sliceInBuffer(reader: *std.Io.Reader, slice: []const u8) bool {
    const buf_start = @intFromPtr(reader.buffer.ptr);
    const buf_end = buf_start + reader.buffer.len;
    const slice_start = @intFromPtr(slice.ptr);
    return slice_start >= buf_start and slice_start + slice.len <= buf_end;
}

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

test "isValidBase" {
    try std.testing.expect(isValidBase('A'));
    try std.testing.expect(isValidBase('T'));
    try std.testing.expect(isValidBase('C'));
    try std.testing.expect(isValidBase('G'));
    try std.testing.expect(isValidBase('N'));
    try std.testing.expect(!isValidBase('X'));
    try std.testing.expect(!isValidBase('@'));
}
