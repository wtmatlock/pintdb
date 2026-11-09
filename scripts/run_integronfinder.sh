#!/bin/bash

# Paths
FASTA="/shared/team/plsdb_integrons/plsdb_2024_05_31_v2/sequences.fasta"
TOPOLOGY="/shared/team/plsdb_integrons/topology.txt"
OUT_DIR="/shared/team/plsdb_integrons/integronfinder_results"

CPU_PER_JOB=1
JOBS=2

mkdir -p "$OUT_DIR"
LOGFILE="$OUT_DIR/run.log"

echo "[$(date)] Starting run" | tee -a "$LOGFILE"

run_seq() {
    acc="$1"
    run_dir="$OUT_DIR/$acc"
    results_subdir="$run_dir/Results_Integron_Finder_${acc}"
    summary="$results_subdir/${acc}.summary"

    # Skip if already done
    if [ -f "$summary" ]; then
        echo "[$(date)] Skipping $acc" | tee -a "$LOGFILE"
        return
    fi

    echo "[$(date)] Running $acc" | tee -a "$LOGFILE"

    mkdir -p "$run_dir"
    tmp="$run_dir/${acc}.fasta"

    # Extract the accession sequence
    seqkit grep -p "$acc" "$FASTA" > "$tmp"

    # Run IntegronFinder
    integron_finder "$tmp" \
        --local-max \
        --promoter-attI \
        --topology-file "$TOPOLOGY" \
        --cpu $CPU_PER_JOB \
        --outdir "$run_dir"

}

# Export for GNU parallel
export -f run_seq
export FASTA OUT_DIR TOPOLOGY CPU_PER_JOB LOGFILE

# Index FASTA once for speed
seqkit faidx "$FASTA"

# Run in parallel
seqkit seq -n "$FASTA" | cut -d ' ' -f1 | parallel -j $JOBS run_seq {}

echo "[$(date)] Finished" | tee -a "$LOGFILE"
