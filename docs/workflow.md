# Workflow

PIntDB uses PLSDB (`2024_05_31_v2`), which contains 72,360 plasmid sequences derived from NCBI. All sequences were processed uniformly; further curation is left to users. The scripts are available in the [GitHub repository](https://github.com/wtmatlock/pintdb).

## Integron annotation

IntegronFinder (v. 2.0.6) was run with `run_integronfinder.sh`, which parallelizes processing and uses seqkit (v. 2.13.0). We used the default parameters with `--local-max --topology-file "$topo_file" --promoter-attI`, using PLSDB topology metadata from `topology.txt`.

When combining results, exclude checkpoint directories such as `integronfinder_results/NZ_CP135169.1/Results_Integron_Finder_NZ_CP135169.1/.ipynb_checkpoints/NZ_CP135169.1-checkpoint.integrons`.

## Element extraction

`extract_regions.R` extracts integron elements to `integrases.fna`, `integrases.faa`, `gene_cassettes.fna`, and `gene_cassettes.faa`, accounting for contig circularity. IntegronFinder's [`integron.py`](https://github.com/gem-pasteur/Integron_Finder/blob/master/integron_finder/integron.py) can generate out-of-bounds coordinates on linear contigs: its `add_promoter` function does not account for search-window truncation at sequence edges. The extraction script clamps coordinates to prevent these errors.

The same script writes `ambiguity_log.csv`, which records non-AGCT bases in the nucleotide sequences. These bases are translated as `X` in the corresponding `.faa` files.

## Gene cassette protein annotation

`gene_cassettes.faa` was annotated with Bakta (v. 1.12.0; full database v. 6.0, including AMRFinderPlus v. 2026-01-21.1) in `bakta_proteins` mode with default parameters.

## Gene cassette protein clustering

`gene_cassettes.faa` was clustered with MMseqs2 (v. 18.8cc5c), using the defaults with `easy-cluster -s 10 --min-seq-id 0.95 -c 0.95 --cov-mode 0 --cluster-mode 0 --alignment-mode 3 --max-seqs $N`, where `$N` is the number of input sequences.

## Plasmid-level annotation

Plasmids were annotated with ISEScan (v. 1.7.3) using default parameters, and with NCBI AMRFinderPlus (v. 4.2.7; database v. 2026-01-21.1) using default parameters plus `--plus`, via `run_amrfinder.sh`.
