//! EcoData.Genomics - Genomics pipeline for water quality analysis.
//!
//! Takes raw DNA sequencing reads from water samples and produces
//! actionable water quality intelligence.

const std = @import("std");

pub const seqio = @import("seqio.zig");
pub const trimmer = @import("trimmer.zig").Trimmer;
pub const kmer = @import("kmer.zig");

test {
    _ = seqio;
    _ = trimmer;
    _ = kmer;
}
