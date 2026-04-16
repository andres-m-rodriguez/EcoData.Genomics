# EcoData.Genomics

A genomics pipeline built in Zig. Takes raw DNA sequencing reads and works them through a series of stages — parsing, quality filtering, k-mer analysis, classification, and scoring — to produce an actionable water quality index.

> **Status:** Core pipeline functional. Database building and binary serialization working.

## The pipeline

```
seqio → trimmer → kmer → genDb → classifier → index
```

**`seqio` — Sequence I/O** ✓

Parses FASTQ and FASTA files. FASTQ records can borrow from the reader buffer or allocate, avoiding unnecessary copies. FASTA sequences stored as concatenated data with line indices.

**`trimmer` — Quality trimmer** ✓

Applies sliding window quality filtering using Phred scores. Removes low-confidence bases from read ends.

**`kmer` — k-mer encoding and counting** ✓

- `encoding`: 2-bit encoding (A=00, C=01, G=10, T=11), packs up to 32 bases into u64
- `Counter`: kmer → count frequency table
- `Index`: kmer → taxon_id classification lookup
- `K` presets: kraken1 (31), kraken2 (35), default (31), minimizer (21)

**`genDb` — Database builder** ✓

- `Builder`: builds kmer index from multiple FASTA reference genomes
- `Database`: loads index from binary file or memory for classification
- Binary format (.egdb): little-endian, k (u8) + count (u64) + entries (u64 kmer, u32 taxon)

**`classifier` — Metagenomics classifier**

*Next up.* Will take reads, extract kmers, look up taxon hits, and return classification.

**`index` — Water quality index**

Translates species abundance into a health score based on contamination indicators.

## How it fits into the bigger picture

EcoData sensors deployed in waterways run 24/7, streaming pH, turbidity, conductivity, temperature, and dissolved oxygen readings into the platform. When those sensors detect an anomaly — a conductivity spike, a turbidity jump — that triggers a field visit.

A researcher collects a water sample, filters it through a 0.22μm membrane to capture microbial biomass, extracts DNA, and sequences it with a MinION on-site or back at the lab. The resulting FASTQ file goes into this pipeline. Within hours the anomaly has a biological explanation.

Sensor data and genomic data together are significantly more powerful than either alone.

## License

MIT
