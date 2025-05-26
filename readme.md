トランスクリプトーム解析パイプライン
===============================

このパイプラインは、SRA から RNA-Seq データを処理し、群間（例：Positive vs Negative）での差次的遺伝子発現（DEG）解析を自動で行います。

主な処理手順：
---------------
1. SRA ID に基づく FASTQ データのダウンロード
2. trim_galore + FastQC によるクオリティトリミング
3. Salmon による発現定量
4. R（tximport + DESeq2）によるDEG解析
5. 結果出力：遺伝子名付きのDEGリスト、正規化済み発現量マトリクス

ファイル構成：
---------------
- config.yml         : パスやツールの設定
- samples.tsv        : サンプル一覧（project, SRA ID, 群など）
- run_analysis.sh    : パイプラインを実行するシェルスクリプト
- run_deseq.R        : RによるDEG解析スクリプト
- environment.yml    : conda環境の構成
- README.md          : この説明ファイル

実行方法：
----------
1. conda 環境の構築（最初のみ）：

   conda env create -f environment.yml
   conda activate transcriptome_analysis

2. パイプラインの実行：

   bash run_analysis.sh

出力ファイル：
---------------
- PRJNAxxxx_DEG.tsv     : DEGリスト（log2FC, padj, gene名など含む）
- PRJNAxxxx_counts.tsv  : 各サンプルにおける発現量（normalized counts）
