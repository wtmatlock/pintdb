# Tutorial

The PIntDB archive contains tool outputs, summary tables, and sequence files.

| File | Description |
| --- | --- |
| `integronfinder_results_integrons.tsv` | Integron elements annotated across all plasmids. |
| `integronfinder_results_summary.tsv` | Counts of complete integrons, CALINs, and In0s for each plasmid. |
| `integrases.fna` | 9,628 integrase nucleotide sequences. Headers match `replicon_ID`\|`integron_ID`\|`element` in `integronfinder_results_integrons.tsv`. |
| `integrases.faa` | Integrase amino acid sequences translated from `integrases.fna`. Ambiguous codons (for example, `N`) are translated as `X`. |
| `gene_cassettes.fna` | 41,397 putative gene cassette coding sequences. Headers match `replicon_ID`\|`integron_ID`\|`element` in `integronfinder_results_integrons.tsv`. |
| `gene_cassettes.faa` | Amino acid sequences translated from `gene_cassettes.fna`. Ambiguous codons (for example, `N`) are translated as `X`. |
| `ambiguity_log.csv` | Translation issues; eight coding sequences contained ambiguous bases. |
| `bakta_annotations.tsv` | Functional annotations for the 41,397 putative gene cassette proteins. |
| `mmseqs2_clusters.tsv` | Gene-family clusters for the 41,397 putative gene cassette proteins. |
| `amrfinder_annotations.tsv` | Plasmid-level annotations of antimicrobial-resistance genes and other clinically relevant determinants. |
| `isescan_annotations.tsv` | Plasmid-level annotations of complete and fragmented insertion sequences. |
| `topology.txt` | IntegronFinder topology input extracted from PLSDB `nuccore.csv` metadata. |
| `raw_outputs.zip` | Raw outputs from IntegronFinder, Bakta, MMseqs2, AMRFinderPlus, and ISEScan. |
| `plsdb_2024_05_31_v2.zip` | Copy of the PLSDB `2024_05_31_v2` archive. |

## Find integrons with *bla*<sub>IMP</sub> variants

Load the integron and annotation tables in R:

```r
library(readr)

integronfinder_results_integrons <- read_delim("integronfinder_results_integrons.tsv", 
                                               delim = "\t", escape_double = FALSE, 
                                               trim_ws = TRUE)

bakta_annotations <- read_delim("bakta_annotations.tsv", 
                                delim = "\t", escape_double = FALSE, 
                                comment = "#", trim_ws = TRUE)
```
Join the annotations to integron elements and select integrons with an IMP annotation:

```r
library(dplyr)
library(stringr)

df <- integronfinder_results_integrons %>%
  mutate(
    fasta_header = ifelse(
      type_elt == "protein" & annotation == "protein",
      paste(ID_replicon, ID_integron, element, sep = "|"),
      NA
    )
  ) %>%
  merge(bakta_annotations, by.x = "fasta_header", by.y = "ID", all.x = TRUE) %>%
  group_by(ID_replicon, ID_integron) %>%
  arrange(pos_beg, .by_group = TRUE) %>%
  select(3, 2, 4, 1, everything()) %>%
  filter(any(str_detect(Gene, regex("IMP", ignore_case = TRUE)), na.rm = TRUE)) %>%
  ungroup()
```
Extract the plasmid accessions for follow-up analysis. This example returns 358 accessions.

```r
imp_plasmids <- df %>% 
  select(ID_replicon) %>%
  unique() %>%
  pull()
```

## Build a conservative gene cassette set

IntegronFinder can miss *attI* and *attC* sites or include elements from the 3′ conserved segment. The following example retains coding sequences flanked by the expected recombination sites.

Start with complete integrons (an integrase and at least one *attC* site), then select coding sequences delimited by *attI* and *attC* sites or by paired *attC* sites:

```r
library(dplyr)
library(readr)
library(zoo)

df <- read_delim("integronfinder_results_integrons.tsv", 
                            delim = "\t", escape_double = FALSE, trim_ws = TRUE) %>%
  filter(type == "complete") %>%
  filter(type_elt %in% c("attC", "attI") | (type_elt == "protein" & annotation == "protein")) %>%
  mutate(midpoint = (pos_beg + pos_end) / 2) %>%
  # identify flanking boundaries for all elements
  group_by(ID_replicon, ID_integron) %>%
  arrange(midpoint, .by_group = TRUE) %>%
  mutate(
    is_boundary = type_elt %in% c("attC", "attI"),
    last_boundary = na.locf(ifelse(is_boundary, type_elt, NA), na.rm = FALSE),
    next_boundary = na.locf(ifelse(is_boundary, type_elt, NA), fromLast = TRUE, na.rm = FALSE)
  ) %>%
  ungroup() %>%
  # filter for proteins flanked by required sites
  filter(
    type_elt == "protein",
    annotation == "protein",
    ((last_boundary == "attC" & next_boundary %in% c("attC", "attI")) |
       (next_boundary == "attC" & last_boundary %in% c("attC", "attI")))
  ) %>%
  mutate(ID = paste(ID_replicon, ID_integron, element, sep="|")) 
```
Remove MMseqs2 families with annotations of concern. This example reduces the set from 41,397 to 20,822 coding sequences:

```r
bakta_annotations <- read_delim("bakta_annotations.tsv", 
                                delim = "\t", escape_double = FALSE, 
                                comment = "#", trim_ws = TRUE)

mmseqs2_clusters <- read_delim("mmseqs2_clusters.tsv", 
                               delim = "\t", escape_double = FALSE, 
                               col_names = FALSE, trim_ws = TRUE) %>%
  rename("representative" = X1, "ID" = X2)

cds_to_keep <- merge(bakta_annotations, mmseqs2_clusters, by.x="ID") %>%
  group_by(representative) %>%
  filter(!any(Gene == "sul1", na.rm = TRUE)) %>%
  filter(!any(Gene == "qacE", na.rm = TRUE)) %>%
  filter(!any(Gene == "qacEdelta1", na.rm = TRUE)) %>%
  filter(!any(Product == "QACEdelta1", na.rm = TRUE)) %>%
  ungroup() %>%
  pull(ID)

df <- df %>%
  filter(ID %in% cds_to_keep)
```
  
