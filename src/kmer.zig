pub const encode = @import("kmer/encoding.zig").encode;
pub const decode = @import("kmer/encoding.zig").decode;
pub const Counter = @import("kmer/Counter.zig");
pub const Index = @import("kmer/Index.zig");

pub const K = struct {
    pub const kraken1: u6 = 31;
    pub const kraken2: u6 = 35;
    pub const default: u6 = 31;
    pub const minimizer: u6 = 21;
};

test {
    _ = @import("kmer/encoding.zig");
    _ = Counter;
    _ = Index;
}
