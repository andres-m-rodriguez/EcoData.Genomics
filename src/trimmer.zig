pub const Trimmer = @import("trimmer/trimmer.zig");

pub const TrimmedRead = struct {
    sequence: []const u8,
    quality: []const u8,
};

test {
    _ = Trimmer;
}
