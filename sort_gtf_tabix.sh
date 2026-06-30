#!/usr/bin/env bash
set -euo pipefail

# 用法：
#   bash sort_gtf_tabix.sh input.gtf
#   bash sort_gtf_tabix.sh input.gtf output.sorted.gtf.gz
#
# 依赖：
#   bgzip, tabix

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 input.gtf[.gz] [output.sorted.gtf.gz]" >&2
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.gtf}.sorted.gtf.gz}"
OUTPUT="${OUTPUT%.gz}.gz"

TMP_HEADER=$(mktemp)
TMP_BODY=$(mktemp)
TMP_SORTED=$(mktemp)

trap 'rm -f "$TMP_HEADER" "$TMP_BODY" "$TMP_SORTED"' EXIT

# 根据输入是否为 .gz 选择读取方式
if [[ "$INPUT" == *.gz ]]; then
    READ_CMD="gzip -dc"
else
    READ_CMD="cat"
fi

# 1. 提取 header 行
$READ_CMD "$INPUT" | grep '^#' > "$TMP_HEADER" || true

# 2. 提取非 header 行并排序
# GTF/GFF 坐标列：
#   第 1 列：seqname / chromosome
#   第 4 列：start
#   第 5 列：end
$READ_CMD "$INPUT" \
    | awk 'BEGIN{FS=OFS="\t"} $0 !~ /^#/ && NF >= 5' \
    | LC_ALL=C sort -k1,1 -k4,4n -k5,5n \
    > "$TMP_BODY"

# 3. 合并 header 和排序后的正文
cat "$TMP_HEADER" "$TMP_BODY" > "$TMP_SORTED"

# 4. bgzip 压缩
bgzip -c "$TMP_SORTED" > "$OUTPUT"

# 5. tabix 建索引
tabix -f -p gff "$OUTPUT"

echo "Done:"
echo "  sorted bgzip file: $OUTPUT"
echo "  tabix index:       ${OUTPUT}.tbi"
