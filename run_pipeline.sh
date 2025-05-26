#!/bin/bash
set -euo pipefail

CONFIG="config.yml"

# 1. Setup
GENOME=$(yq '.genome' "$CONFIG")
REFGENIE_CONF=$(yq '.refgenie_config' "$CONFIG")
DATA_DIR=$(yq '.data_dir' "$CONFIG")
TX2GENE_FILE=$(yq '.tx2gene_file' "$CONFIG")
THREADS=$(yq '.threads' "$CONFIG")

# 2. Refgenie index 準備（なければ取得）
if ! refgenie list -c "$REFGENIE_CONF" | grep -q "$GENOME.*salmon_sa_index"; then
    echo "[*] Pulling assets for $GENOME"
    refgenie pull -c "$REFGENIE_CONF" -g "$GENOME" -a fasta,gtf,fasta_txome,salmon_sa_index,gencode_gtf
fi

# 3. tx2gene生成（なければ）
if [[ ! -f "$TX2GENE_FILE" ]]; then
    GTF=$(refgenie seek -c "$REFGENIE_CONF" "${GENOME}/gencode_gtf")
    echo "[*] Generating tx2gene.tsv"
    gffread "$GTF" -T -o temp.gtf
    awk '$3 == "transcript" {print $10"\t"$14}' temp.gtf | sed 's/"//g;s/;//g' > "$TX2GENE_FILE"
    rm -f temp.gtf
fi

# 4. 各プロジェクトの処理
PROJECTS=$(yq '.projects | keys | .[]' "$CONFIG")
for PRJ in $PROJECTS; do
    echo "[*] Processing $PRJ"
    PRJ_DIR="${DATA_DIR}/${PRJ}/quant"
    mkdir -p "$PRJ_DIR"

    N=$(yq ".projects.$PRJ | length" "$CONFIG")
    for ((i=0; i<N; i++)); do
        SAMPLE=$(yq ".projects.$PRJ[$i].sample" "$CONFIG")
        GROUP=$(yq ".projects.$PRJ[$i].group" "$CONFIG")
        SAMPLE_DIR="${DATA_DIR}/${PRJ}/HBV_${GROUP}/${SAMPLE}"
        mkdir -p "$SAMPLE_DIR"

        # SRA download
        if [[ ! -f "${SAMPLE_DIR}/${SAMPLE}_1.fq.gz" ]]; then
            prefetch "$SAMPLE"
            fasterq-dump "$SAMPLE" -O "$SAMPLE_DIR" --split-files --gzip
        fi

        # Trim Galore
        fq1="${SAMPLE_DIR}/${SAMPLE}_1.fq.gz"
        fq2="${SAMPLE_DIR}/${SAMPLE}_2.fq.gz"
        trim_galore --paired --cores 4 -o "$SAMPLE_DIR" "$fq1" "$fq2"

        fq1t="${SAMPLE_DIR}/${SAMPLE}_1_val_1.fq.gz"
        fq2t="${SAMPLE_DIR}/${SAMPLE}_2_val_2.fq.gz"
        OUTDIR="${PRJ_DIR}/${SAMPLE}"
        mkdir -p "$OUTDIR"

        # Salmon
        INDEX=$(refgenie seek -c "$REFGENIE_CONF" "${GENOME}/salmon_sa_index")
        salmon quant -i "$INDEX" -l A -1 "$fq1t" -2 "$fq2t" -p "$THREADS" \
            --validateMappings -o "$OUTDIR"
    done

    # RでDESeq2解析
    Rscript run_deseq.R "$PRJ" "$TX2GENE_FILE" "$DATA_DIR"
done

echo "完了"
