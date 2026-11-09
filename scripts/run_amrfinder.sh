#!/bin/bash

# Paths
FASTA="/shared/team/plsdb_integrons/plsdb_2024_05_31_v2/sequences.fasta"
OUT_DIR="/shared/team/plsdb_integrons/amrfinder_results"

CPU_PER_JOB=1
JOBS=2

mkdir -p "$OUT_DIR"
LOGFILE="$OUT_DIR/run.log"

echo "[$(date)] Starting AMRFinder run" | tee -a "$LOGFILE"

run_seq() {
    acc="$1"
    run_dir="$OUT_DIR/$acc"
    out_file="$run_dir/${acc}_amrfinder.tsv"

    # Skip if already done
    if [ -f "$out_file" ]; then
        echo "[$(date)] Skipping $acc" | tee -a "$LOGFILE"
        return
    fi

    echo "[$(date)] Running $acc" | tee -a "$LOGFILE"

    mkdir -p "$run_dir"
    tmp="$run_dir/${acc}.fasta"

    # Extract the accession sequence (match only first token)
    seqkit grep -p "$acc" "$FASTA" > "$tmp"

    # Run AMRFinder
    amrfinder --plus --nucleotide "$tmp" --output "$out_file"
}

# Export for GNU parallel
export -f run_seq
export FASTA OUT_DIR LOGFILE

# Index FASTA once for speed
seqkit faidx "$FASTA"

# Run in parallel
seqkit seq -n "$FASTA" | cut -d ' ' -f1 | parallel -j $JOBS run_seq {}

echo "[$(date)] Finished" | tee -a "$LOGFILE"