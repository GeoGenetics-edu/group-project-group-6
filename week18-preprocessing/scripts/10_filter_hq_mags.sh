#!/bin/bash
#SBATCH --job-name=filter_hq_mags                                       # name shown in squeue. It can be anything.
#SBATCH --output=/maps/projects/course_1/scratch/group6/group-project-group-6/week18-preprocessing/logs/%x_%j.out   # stdout log. Make sure to create your logs folder
#SBATCH --error=/maps/projects/course_1/scratch/group6/group-project-group-6/week18-preprocessing/logs/%x_%j.err    # stderr log
#SBATCH --ntasks=1                                               # one task (one process group)
#SBATCH --cpus-per-task=1                                       # CPUs available to that task
#SBATCH --mem-per-cpu=4G                                        # RAM per CPU (total = cpus * mem-per-cpu)
#SBATCH --time=05:00:00                                          # HH:MM:SS wall-clock limit
#SBATCH --mail-type=end                                          # email me when it finishes
#SBATCH --mail-type=fail                                         # email me if it fails
#SBATCH --mail-user=zxn328@alumni.ku.dk                        # your KU email
#SBATCH --reservation=NBIB25004U                                 # class reservation. Specific for this course. Bent reserved a node for us.
#SBATCH --account=teaching                                       # class billing account
# filter_hq_mags.sh — Copy high-quality MAGs to a single folder.
#
# A bin is considered high-quality when:
#     Completeness - 5 * Contamination >= 50
#
# Usage:
#   filter_hq_mags.sh -c <checkm2.tsv> -b <bins_dir> -o <output_dir> [-e .fa]
#
# Options:
#   -c, --checkm2 FILE   CheckM2 quality_report.tsv
#   -b, --bins    DIR    Directory containing the bin fasta files
#                        (searched recursively)
#   -o, --output  DIR    Destination directory (default: all_hq_mags)
#   -e, --ext     STR    Bin file extension (default: .fa)
#   -h, --help           Show this help
# ---------------------------------------------------------------------------

set -euo pipefail

CHECKM2_TSV=""
BINS_DIR=""
OUT_DIR="all_hq_mags"
EXT=".fa"

usage() { sed -n '2,19p' "$0"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--checkm2) CHECKM2_TSV="$2"; shift 2 ;;
        -b|--bins)    BINS_DIR="$2";    shift 2 ;;
        -o|--output)  OUT_DIR="$2";     shift 2 ;;
        -e|--ext)     EXT="$2";         shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

[[ -f "$CHECKM2_TSV" ]] || { echo "ERROR: checkm2 tsv not found: $CHECKM2_TSV" >&2; exit 1; }
[[ -d "$BINS_DIR" ]]    || { echo "ERROR: bins dir not found: $BINS_DIR"       >&2; exit 1; }

mkdir -p "$OUT_DIR"

# --- Pull HQ bin names from the checkm2 table ------------------------------
# Column 1 = Name, 2 = Completeness, 3 = Contamination
mapfile -t HQ_BINS < <(
    awk -F'\t' 'NR>1 && ($2 - 5*$3) >= 50 { print $1 }' "$CHECKM2_TSV"
)

echo "High-quality bins found in table: ${#HQ_BINS[@]}"

COPIED=0
MISSING=()
for name in "${HQ_BINS[@]}"; do
    # The checkm2 "Name" column is the bin filename without extension.
    src="$(find "$BINS_DIR" -type f -name "${name}${EXT}" -print -quit)"
    if [[ -z "$src" ]]; then
        MISSING+=( "$name" )
        continue
    fi
    cp -f "$src" "${OUT_DIR}/${name}${EXT}"
    COPIED=$(( COPIED + 1 ))
done

echo "Copied ${COPIED} HQ bin(s) to: ${OUT_DIR}"
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "WARN: ${#MISSING[@]} bin(s) listed as HQ but not found under ${BINS_DIR}:" >&2
    printf '  %s\n' "${MISSING[@]}" >&2
fi