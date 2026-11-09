library(Biostrings)
library(readr)
library(stringr)

integron_dir <- "/shared/team/plsdb_integrons/integronfinder_results"

ambiguity_log_file <- "/shared/team/plsdb_integrons/ambiguity_log.csv"

output_fasta_nn <- "/shared/team/plsdb_integrons/gene_cassettes.fna"
output_fasta_aa <- "/shared/team/plsdb_integrons/gene_cassettes.faa"

output_intI_nn <- "/shared/team/plsdb_integrons/integrases.fna"
output_intI_aa <- "/shared/team/plsdb_integrons/integrases.faa"

file.remove(output_fasta_nn, output_fasta_aa, output_intI_nn, output_intI_aa)
file.create(output_fasta_nn, output_fasta_aa, output_intI_nn, output_intI_aa)

writeLines("sequence,issue", ambiguity_log_file)

files <- list.files(integron_dir, pattern = "\\.integrons$", recursive = TRUE, full.names = TRUE)

get_fasta <- function(f) {
  sample_dir <- dirname(dirname(f))
  sample_name <- basename(sample_dir)
  file.path(sample_dir, paste0(sample_name, ".fasta"))
}

fasta_map <- split(files, vapply(files, get_fasta, character(1)))

safe_extract <- function(s, start, end, topo) {
  
  w <- length(s)
  
  if (is.na(start) || is.na(end) || is.na(topo)) {
    return(DNAString(""))
  }
  
  start <- ((as.integer(start) - 1L) %% w) + 1L
  end   <- ((as.integer(end) - 1L) %% w) + 1L
  
  if (topo == "circ" && start > end) {
    return(xscat(
      subseq(s, start, w),
      subseq(s, 1, end)
    ))
  }
  
  if (start > end) return(DNAString(""))
  subseq(s, start, end)
}

extract_and_translate <- function(df_subset, seqs, out_nn, out_aa) {
  
  df_subset <- df_subset[df_subset$ID_replicon %in% names(seqs), , drop = FALSE]
  if (nrow(df_subset) == 0) return()
  
  target_seqs <- seqs[df_subset$ID_replicon]
  ref_widths <- width(target_seqs)
  
  seq_list <- mapply(
    function(s, start, end, w, topo)
      safe_extract(s, start, end, topo),
    target_seqs,
    df_subset$pos_beg,
    df_subset$pos_end,
    ref_widths,
    df_subset$considered_topology,
    SIMPLIFY = FALSE
  )
  
  if (length(seq_list) == 0) return()
  
  dna <- DNAStringSet(seq_list)
  
  names(dna) <- paste(
    df_subset$ID_replicon,
    df_subset$ID_integron,
    df_subset$element,
    sep = "|"
  )
  
  # strand handling
  neg <- df_subset$strand == -1
  if (any(neg)) {
    dna[neg] <- reverseComplement(dna[neg])
  }
  
  writeXStringSet(dna, out_nn, append = TRUE)
  
  # translation + QC
  chars <- as.character(dna)
  no_gap <- gsub("-", "", chars)
  
  ambig <- str_detect(chars, "[^AGCTagct]")
  bad3  <- nchar(no_gap) %% 3 != 0
  
  if (any(ambig | bad3)) {
    bad <- ambig | bad3
    
    write_csv(
      data.frame(
        sequence = names(dna)[bad],
        issue = ifelse(
          ambig[bad] & bad3[bad], "length not div 3 and ambiguous",
          ifelse(bad3[bad], "length not div 3", "ambiguous")
        )
      ),
      ambiguity_log_file,
      append = TRUE,
      col_names = FALSE
    )
  }
  
  ok <- which(!bad3)
  if (length(ok) > 0) {
    clean <- gsub("[^AGCTagct]", "N", gsub("-", "", chars[ok]))
    aa <- translate(DNAStringSet(clean), if.fuzzy.codon = "X")
    names(aa) <- names(dna)[ok]
    writeXStringSet(aa, out_aa, append = TRUE)
  }
}

for (fasta_file in names(fasta_map)) {
  
  message("Processing: ", fasta_file)
  if (!file.exists(fasta_file)) next
  
  seqs <- readDNAStringSet(fasta_file)
  names(seqs) <- sub(" .*", "", names(seqs))
  
  for (f in fasta_map[[fasta_file]]) {
    
    df <- read_tsv(f, comment = "#", show_col_types = FALSE, lazy = FALSE)
    if (nrow(df) == 0) next
    
    df <- df[df$ID_replicon %in% names(seqs), , drop = FALSE]
    if (nrow(df) == 0) next
    
    extract_and_translate(
      df[df$annotation == "protein", , drop = FALSE],
      seqs,
      output_fasta_nn,
      output_fasta_aa
    )
    
    extract_and_translate(
      df[df$annotation == "intI", , drop = FALSE],
      seqs,
      output_intI_nn,
      output_intI_aa
    )
  }
  
  rm(seqs)
  gc(verbose = FALSE)
}