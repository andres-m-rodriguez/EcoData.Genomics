# EcoData.Genomics

A genomics pipeline built in Zig. Takes raw DNA sequencing reads and works them through a series of stages — parsing, quality filtering, k-mer analysis, classification, and scoring — to produce an actionable water quality index.

> **Status:** Early development. Currently building `seqio`, the sequence I/O layer.

## The pipeline

```
seqio → trimmer → kmer → classifier → index
```

**`seqio` — Sequence I/O** ← currently being built

The entry point. Reads and parses FASTQ and FASTA files — the standard formats that DNA sequencing output produces. A FASTQ file is a list of DNA reads, where each read has four parts: an identifier, the DNA sequence itself (a string of A, T, C, G letters), a separator, and a quality score string encoding how confident the sequencer was about each letter it read.

This stage produces structured records that the rest of the pipeline consumes. No analysis yet — just turning raw files into something the next stage can work with.

**`trimmer` — Quality trimmer**

Raw sequencing reads are noisy. The ends of reads in particular tend to have low confidence scores — the sequencer was less certain about those bases. Before doing any biological analysis on the data, unreliable reads and low-quality ends need to be removed.

This stage takes the parsed records from `seqio`, applies quality thresholds using the Phred scores encoded in the quality string, and outputs only the reads worth analyzing.

**`kmer` — k-mer counter**

A k-mer is a substring of length k. Every DNA sequence can be broken into overlapping k-mers — for example the sequence `ATCGAT` with k=3 gives `ATC`, `TCG`, `CGA`, `GAT`. Counting how frequently each k-mer appears across all reads produces a frequency table that acts as a fingerprint of the sample.

Different organisms have characteristic k-mer distributions. This fingerprint is what the classifier uses to identify what's in the sample — without needing to fully assemble genomes from the reads, which is much more computationally expensive.

**`classifier` — Metagenomics classifier**

Takes the k-mer frequency table and compares it against reference databases of known organism k-mer profiles (Silva 16S rRNA database for bacteria, NCBI RefSeq for broader coverage). Outputs a species abundance table — a list of organisms identified in the sample with their relative percentages.

**`index` — Water quality index**

Translates the species abundance table into a single health score. Maps microbial composition against known contamination indicators and ecological health benchmarks. The final output that integrates with EcoData.

## How it fits into the bigger picture

EcoData sensors deployed in waterways run 24/7, streaming pH, turbidity, conductivity, temperature, and dissolved oxygen readings into the platform. When those sensors detect an anomaly — a conductivity spike, a turbidity jump — that triggers a field visit.

A researcher collects a water sample, filters it through a 0.22μm membrane to capture microbial biomass, extracts DNA, and sequences it with a MinION on-site or back at the lab. The resulting FASTQ file goes into this pipeline. Within hours the anomaly has a biological explanation.

Sensor data and genomic data together are significantly more powerful than either alone.

## License

MIT
