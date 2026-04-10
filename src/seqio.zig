//! Sequence I/O for FASTA/FASTQ formats.
//!
//! Supports streaming reads from MinION sequencing output.
//! FASTQ files contain per-base quality scores, FASTA files do not.

const std = @import("std");

pub const Fastq = @import("seqio/Fastq.zig");
pub const Fasta = @import("seqio/Fasta.zig");
pub const phred = @import("seqio/phred.zig");

test {
    _ = Fastq;
    _ = Fasta;
    _ = phred;
}
