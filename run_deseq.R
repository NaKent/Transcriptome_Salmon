args <- commandArgs(trailingOnly=TRUE)
project <- args[1]
tx2gene_file <- args[2]
data_dir <- args[3]

library(tximport)
library(DESeq2)
library(readr)
library(apeglm)
library(biomaRt)

samples <- list.files(file.path(data_dir, project, "quant"))
sample_table <- data.frame(
  name = samples,
  file = file.path(data_dir, project, "quant", samples, "quant.sf"),
  group = ifelse(grepl("Negative", samples), "Negative", "Positive")
)

tx2gene <- read_tsv(tx2gene_file, col_names = FALSE)
colnames(tx2gene) <- c("TXNAME", "GENEID")

txi <- tximport(sample_table$file, type = "salmon", tx2gene = tx2gene)
dds <- DESeqDataSetFromTximport(txi, colData = sample_table, design = ~ group)
dds <- DESeq(dds)
res <- lfcShrink(dds, coef=2, type="apeglm")
resOrdered <- res[order(res$padj), ]

# アノテーション付加
ensembl <- useEnsembl(biomart = "genes", dataset = "hsapiens_gene_ensembl")
annots <- getBM(attributes = c("ensembl_gene_id", "hgnc_symbol", "description"),
                filters = "ensembl_gene_id",
                values = gsub("\\..*", "", rownames(resOrdered)),
                mart = ensembl)
final <- merge(as.data.frame(resOrdered), annots,
               by.x="row.names", by.y="ensembl_gene_id", all.x=TRUE)

# 出力
write_tsv(final, paste0(project, "_DEG.tsv"))
write_tsv(as.data.frame(counts(dds, normalized=TRUE)), paste0(project, "_counts.tsv"))
