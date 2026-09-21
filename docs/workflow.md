# Workflow

PIntDB is built on PLSDB (v. 2024_05_31_v2), a database of 72,360 plasmid sequences derived from NCBI. We processed all sequences uniformly, and leave any further curation to the user. The scripts used are available in the [GitHub repository](https://github.com/wtmatlock/pintdb).

## Integron annotation

We ran IntegronFinder (v. 2.0.6) with the script `run_integronfinder.sh`, which parallelises the job and depends on seqkit (v. 2.13.0). We used default parameters except `--local-max --topology-file "$topo_file" --promoter-attI`, using the PLSDB topology metadata as input (`topology.txt`).

If you re-run this yourself, watch out for checkpoint directories when combining results at the end e.g. `integronfinder_results/NZ_CP135169.1/Results_Integron_Finder_NZ_CP135169.1/.ipynb_checkpoints/NZ_CP135169.1-checkpoint.integrons`

## Element extraction

We extracted the integron elements using `extract_regions.R`, which writes `integrases.fna`, `integrases.faa`, `gene_cassettes.fna`, and `gene_cassettes.faa`. This script accounted for contig circularity. We noted that in IntegronFinder's [`integron.py`](https://github.com/gem-pasteur/Integron_Finder/blob/master/integron_finder/integron.py) script, the `add_promoter` function could generate out-of-bounds coordinates on linear contigs because its coordinate maths failed to account for search-window truncation at sequence edges. We therefore clamped extractions to avoid errors.

The `ambiguity_log.csv` report, also written by `extract_regions.R`, records any non-AGCT bases in `gene_cassettes.fna` and `integrases.fna` entries. These were translated to X's in `gene_cassettes.faa` and `integrases.faa`, respectively.

## Gene cassette protein annotation

We annotated `gene_cassettes.faa` using Bakta (v. 1.12.0 with full database v. 6.0 including AMRFinderPlus v. 2026-01-21.1) in `bakta_proteins` mode with default parameters.

## Gene cassette protein clustering

We clustered `gene_cassettes.faa` using MMseqs2 (v. 18.8cc5c) with default parameters except `easy-cluster -s 10 --min-seq-id 0.95 -c 0.95 --cov-mode 0 --cluster-mode 0 --alignment-mode 3 --max-seqs $N`, where `$N` was the number of input sequences.

## Plasmid-level annotation

We also annotated the plasmids using ISEScan (v. 1.7.3) with default parameters, and NCBI AMRFinderPlus (v. 4.2.7 with db v. 2026-01-21.1) with default parameters except `--plus`, using `run_amrfinder.sh`.
