## EcoData.Genomics

A genomics pipeline that takes raw DNA sequencing reads from water samples and produces actionable water quality intelligence — from parsing sequencing output all the way to species identification and health scoring.

Built in Zig. Intended to eventually ship as a module inside the [EcoData](https://ecodatapr.com) platform alongside AquaTrack IoT sensor deployments in Puerto Rico's waterways.

> **Status:** Early development. Currently building `seqio`, the sequence I/O layer.

## What this does

Water quality monitoring traditionally relies on chemical sensors — pH, turbidity, conductivity, temperature. Those sensors tell you *something is wrong* but not *what* is wrong biologically.

EcoData.Genomics adds a biological layer. Water samples collected from the field get sequenced using a portable Oxford Nanopore MinION device, producing raw DNA reads. This pipeline takes those reads and works through a series of stages to ultimately answer: **what organisms are living in this water, and is it safe?**

## The pipeline

```
seqio → trimmer → kmer → classifier → index
```

**`seqio` — Sequence I/O** ← currently being built

The entry point. Reads and parses FASTQ and FASTA files — the standard formats that MinION sequencing output produces. A FASTQ file is a list of DNA reads, where each read has four parts: an identifier, the DNA sequence itself (a string of A, T, C, G letters), a separator, and a quality score string encoding how confident the sequencer was about each letter it read.

This stage produces structured records that the rest of the pipeline consumes. No analysis yet — just turning raw files into something the next stage can work with.

**`trimmer` — Quality trimmer**

Raw sequencing reads are noisy. The ends of reads in particular tend to have low confidence scores — the sequencer was less certain about those bases. Before doing any biological analysis on the data, unreliable reads and low-quality ends need to be removed.

This stage takes the parsed records from `seqio`, applies quality thresholds using the Phred scores encoded in the quality string, and outputs only the reads worth analyzing. What sequencing labs do before any downstream work.

**`kmer` — k-mer counter**

A k-mer is a substring of length k. Every DNA sequence can be broken into overlapping k-mers — for example the sequence `ATCGAT` with k=3 gives `ATC`, `TCG`, `CGA`, `GAT`. Counting how frequently each k-mer appears across all reads produces a frequency table that acts as a fingerprint of the sample.

Different organisms have characteristic k-mer distributions. This fingerprint is what the classifier uses to identify what's in the sample — without needing to fully assemble genomes from the reads, which is much more computationally expensive.

**`classifier` — Metagenomics classifier**

Takes the k-mer frequency table and compares it against reference databases of known organism k-mer profiles (Silva 16S rRNA database for bacteria, NCBI RefSeq for broader coverage). Outputs a species abundance table — a list of organisms identified in the sample with their relative percentages.

This is the first truly actionable output. A water sample that comes back with high *E. coli* or *Enterococcus* abundance is a contamination signal. A sample with high biodiversity and no known pathogens is a healthy ecosystem signal.

**`index` — Water quality index**

Translates the species abundance table into a single health score, similar to how a credit score condenses complex financial history into one number. Maps microbial composition against known contamination indicators and ecological health benchmarks.

This score is what eventually posts to the EcoData platform, where it gets correlated with continuous sensor readings from AquaTrack deployments at the same locations. Sensors provide the early warning, genomics provides the biological diagnosis.

## How it fits into the bigger picture

AquaTrack IoT sensors deployed in waterways run 24/7, streaming pH, turbidity, conductivity, temperature, and dissolved oxygen readings into EcoData. When those sensors detect an anomaly — a conductivity spike, a turbidity jump — that triggers a field visit.

A researcher collects a water sample, filters it through a 0.22μm membrane to capture microbial biomass, extracts DNA, and sequences it with a MinION on-site or back at the lab. The resulting FASTQ file goes into this pipeline. Within hours the anomaly has a biological explanation.

Sensor data and genomic data together are significantly more powerful than either alone.

## License

MIT EcoData.Genomics

A genomics pipeline that takes raw DNA sequencing reads from water samples and produces actionable water quality intelligence — from parsing sequencing output all the way to species identification and health scoring.

Built in Zig. Intended to eventually ship as a module inside the [EcoData](https://ecodatapr.com) platform alongside AquaTrack IoT sensor deployments in Puerto Rico's waterways.

> **Status:** Early development. Currently building `seqio`, the sequence I/O layer.

## What this does

Water quality monitoring traditionally relies on chemical sensors — pH, turbidity, conductivity, temperature. Those sensors tell you *something is wrong* but not *what* is wrong biologically.

EcoData.Genomics adds a biological layer. Water samples collected from the field get sequenced using a portable Oxford Nanopore MinION device, producing raw DNA reads. This pipeline takes those reads and works through a series of stages to ultimately answer: **what organisms are living in this water, and is it safe?**

## The pipeline

```
seqio → trimmer → kmer → classifier → index
```

**`seqio` — Sequence I/O** ← currently being built

The entry point. Reads and parses FASTQ and FASTA files — the standard formats that MinION sequencing output produces. A FASTQ file is a list of DNA reads, where each read has four parts: an identifier, the DNA sequence itself (a string of A, T, C, G letters), a separator, and a quality score string encoding how confident the sequencer was about each letter it read.

This stage produces structured records that the rest of the pipeline consumes. No analysis yet — just turning raw files into something the next stage can work with.

**`trimmer` — Quality trimmer**

Raw sequencing reads are noisy. The ends of reads in particular tend to have low confidence scores — the sequencer was less certain about those bases. Before doing any biological analysis on the data, unreliable reads and low-quality ends need to be removed.

This stage takes the parsed records from `seqio`, applies quality thresholds using the Phred scores encoded in the quality string, and outputs only the reads worth analyzing. What sequencing labs do before any downstream work.

**`kmer` — k-mer counter**

A k-mer is a substring of length k. Every DNA sequence can be broken into overlapping k-mers — for example the sequence `ATCGAT` with k=3 gives `ATC`, `TCG`, `CGA`, `GAT`. Counting how frequently each k-mer appears across all reads produces a frequency table that acts as a fingerprint of the sample.

Different organisms have characteristic k-mer distributions. This fingerprint is what the classifier uses to identify what's in the sample — without needing to fully assemble genomes from the reads, which is much more computationally expensive.

**`classifier` — Metagenomics classifier**

Takes the k-mer frequency table and compares it against reference databases of known organism k-mer profiles (Silva 16S rRNA database for bacteria, NCBI RefSeq for broader coverage). Outputs a species abundance table — a list of organisms identified in the sample with their relative percentages.

This is the first truly actionable output. A water sample that comes back with high *E. coli* or *Enterococcus* abundance is a contamination signal. A sample with high biodiversity and no known pathogens is a healthy ecosystem signal.

**`index` — Water quality index**

Translates the species abundance table into a single health score, similar to how a credit score condenses complex financial history into one number. Maps microbial composition against known contamination indicators and ecological health benchmarks.

This score is what eventually posts to the EcoData platform, where it gets correlated with continuous sensor readings from AquaTrack deployments at the same locations. Sensors provide the early warning, genomics provides the biological diagnosis.

## How it fits into the bigger picture

AquaTrack IoT sensors deployed in waterways run 24/7, streaming pH, turbidity, conductivity, temperature, and dissolved oxygen readings into EcoData. When those sensors detect an anomaly — a conductivity spike, a turbidity jump — that triggers a field visit.

A researcher collects a water sample, filters it through a 0.22μm membrane to capture microbial biomass, extracts DNA, and sequences it with a MinION on-site or back at the lab. The resulting FASTQ file goes into this pipeline. Within hours the anomaly has a biological explanation.

Sensor data and genomic data together are significantly more powerful than either alone.

## License

MIT
