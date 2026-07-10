#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 input.gtf[.gz] [output.sorted.gtf.gz]" >&2
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.gtf}.sorted.gtf.gz}"
OUTPUT="${OUTPUT%.gz}.gz"

TMP_HEADER=$(mktemp)
TMP_BODY_SORTED=$(mktemp)
TMP_SORTED_GTF=$(mktemp)

trap 'rm -f "$TMP_HEADER" "$TMP_BODY_SORTED" "$TMP_SORTED_GTF"' EXIT

# 检查依赖
command -v bgzip >/dev/null 2>&1 || { echo "Error: bgzip not found" >&2; exit 1; }
command -v tabix >/dev/null 2>&1 || { echo "Error: tabix not found" >&2; exit 1; }

# zcat -f 可以同时读取普通文本和 .gz 文件
READ_CMD="zcat -f"

# 1. 提取注释行
$READ_CMD "$INPUT" \
    | awk 'BEGIN{FS=OFS="\t"} /^#/ {print}' \
    > "$TMP_HEADER"

# 2. 提取正文并严格按：
#    第 1 列 seqname
#    第 4 列 start
#    第 5 列 end
# 排序
$READ_CMD "$INPUT" \
    | awk 'BEGIN{FS=OFS="\t"} $0 !~ /^#/ && NF >= 5 {print}' \
    | LC_ALL=C sort -t $'\t' -k1,1 -k4,4n -k5,5n \
    > "$TMP_BODY_SORTED"

# 3. 合并 header 和排序后的正文
cat "$TMP_HEADER" "$TMP_BODY_SORTED" > "$TMP_SORTED_GTF"

# 4. bgzip 压缩
bgzip -f -c "$TMP_SORTED_GTF" > "$OUTPUT"

# 5. tabix 建索引
# GTF/GFF:
#   -s 1: sequence/chromosome 在第 1 列
#   -b 4: start 在第 4 列
#   -e 5: end 在第 5 列
tabix -f -s 1 -b 4 -e 5 "$OUTPUT"

echo "Done:"
echo "  sorted bgzip file: $OUTPUT"
echo "  tabix index:       ${OUTPUT}.tbi"
