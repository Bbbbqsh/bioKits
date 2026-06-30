#!/usr/bin/env bash
set -euo pipefail

SAMTOOLS="/public1/home/ganhf/biosoft/samtools-1.23.1/bin/samtools"

if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") <input.bam>" >&2
    exit 1
fi

bam_path="$1"
if [[ ! -r "$bam_path" ]]; then
    echo "Error: cannot read BAM file: $bam_path" >&2
    exit 1
fi

"$SAMTOOLS" view -F 0x900 "$bam_path" | awk '
    BEGIN { total=0; adjacent_reads=0; non_adjacent_reads=0; prev="" }
    {
      total++
      if (prev == $1) {
        adjacent_reads += 2
        prev = ""
      } else {
        if (prev != "") non_adjacent_reads++
        prev = $1
      }
    }
    END {
      if (prev != "") non_adjacent_reads++
      print "total_primary_records =", total
      print "adjacent_reads =", adjacent_reads
      print "non_adjacent_reads =", non_adjacent_reads
      if (total > 0) {
        print "adjacent_ratio =", adjacent_reads / total
        print "non_adjacent_ratio =", non_adjacent_reads / total
      } else {
        print "adjacent_ratio =", "NA"
        print "non_adjacent_ratio =", "NA"
      }
    }'
