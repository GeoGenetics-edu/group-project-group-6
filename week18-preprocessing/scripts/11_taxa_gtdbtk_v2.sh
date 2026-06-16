#!/bin/bash
#SBATCH --job-name=taxanomic                                    # name shown in squeue. It can be anything.
#SBATCH --output=/maps/projects/course_1/scratch/group6/group-project-group-6/week18-preprocessing/logs/%x_%j.out   # stdout log. Make sure to create your logs folder
#SBATCH --error=/maps/projects/course_1/scratch/group6/group-project-group-6/week18-preprocessing/logs/%x_%j.err    # stderr log
#SBATCH --ntasks=1                                               # one task (one process group)
#SBATCH --cpus-per-task=30                                       # CPUs available to that task
#SBATCH --mem-per-cpu=6G                                        # RAM per CPU (total = cpus * mem-per-cpu)
#SBATCH --time=10:00:00                                          # HH:MM:SS wall-clock limit
#SBATCH --mail-type=end                                          # email me when it finishes
#SBATCH --mail-type=fail                                         # email me if it fails
#SBATCH --mail-user=zxn328@alumni.ku.dk                        # your KU email
#SBATCH --reservation=NBIB25004U                                 # class reservation. Specific for this course. Bent reserved a node for us.
#SBATCH --account=teaching                                       # class billing account
#
# run_gtdbtk.sh — Run GTDB-Tk 'classify_wf' on a folder of MAGs / bins.
#
# Usage:
#   run_gtdbtk.sh -i <genome_dir> -o <out_dir> [options]
#
# Required:
#   -i, --input DIR          Folder containing genome / bin FASTA files
#   -o, --output DIR         Output directory for GTDB-Tk results
#
# Optional:
#   -d, --database PATH      Path to GTDB-Tk reference data (GTDBTK_DATA_PATH)
#                            NOTE: GTDB-Tk 2.7 requires the R232 data package.
#                            (default: /maps/datasets/globe_databases/gtdbtk_db/release232)
#   -t, --cpus INT           Number of CPUs                       (default: 30)
#   -x, --extension STR      File extension of genomes            (default: fa)
#       --no-place-species   Do NOT pass --place_species (default: --place_species IS passed)
#                            In 2.7 ANI screening is always done globally; --place_species
#                            additionally runs the pplacer tree-placement step.
#   -e, --extra "STR"        Extra raw arguments forwarded to gtdbtk (quoted)
#   -f, --force              Overwrite existing output directory
#   -h, --help               Show this help and exit
# ---------------------------------------------------------------------------

# ---- 0. Load Modules -------------------------------------------------------

module purge
module load gtdbtk/2.7.1
gtdbtk --version    # sanity check
set -euo pipefail

# ---------- defaults --------------------------------------------------------
CPUS=30
EXTENSION="fa"
# GTDB-Tk 2.7 requires R232 data. Update this path once release232 is staged on the cluster.
DATABASE="/maps/projects/course_1/data/gtdb232/release232"
EXTRA_ARGS=""
PLACE_SPECIES=1
FORCE=0

INPUT_DIR=""
OUT_DIR=""

# ---------- usage -----------------------------------------------------------
usage() {
    cat <<EOF
Usage:
  $(basename "$0") -i <genome_dir> -o <out_dir> [options]

Required:
  -i, --input DIR          Folder containing genome / bin FASTA files
  -o, --output DIR         Output directory for GTDB-Tk results

Optional:
  -d, --database PATH      Path to GTDB-Tk reference data (GTDBTK_DATA_PATH)
                           NOTE: 2.7 requires the R232 data package.
                           (default: ${DATABASE})
  -t, --cpus INT           Number of CPUs                       (default: ${CPUS})
  -x, --extension STR      File extension of genomes            (default: ${EXTENSION})
      --no-place-species   Do NOT pass --place_species
                           (by default --place_species IS passed, which runs pplacer
                            tree placement on top of the global skani ANI screen.
                            Disable for a faster ANI-only run.)
  -e, --extra "STR"        Extra raw arguments forwarded to gtdbtk (quoted)
  -f, --force              Overwrite existing output directory
  -h, --help               Show this help and exit
EOF
}

# ---------- arg parsing -----------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input)          INPUT_DIR="$2";   shift 2 ;;
        -o|--output)         OUT_DIR="$2";     shift 2 ;;
        -d|--database)       DATABASE="$2";    shift 2 ;;
        -t|--cpus)           CPUS="$2";        shift 2 ;;
        -x|--extension)      EXTENSION="$2";   shift 2 ;;
           --no-place-species) PLACE_SPECIES=0; shift   ;;
        -e|--extra)          EXTRA_ARGS="$2";  shift 2 ;;
        -f|--force)          FORCE=1;          shift   ;;
        -h|--help)           usage; exit 0 ;;
        *)  echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

# ---------- sanity checks ---------------------------------------------------
command -v gtdbtk >/dev/null 2>&1 || {
    echo "ERROR: 'gtdbtk' not found in PATH." >&2
    exit 1
}

if [[ -z "$INPUT_DIR" || -z "$OUT_DIR" ]]; then
    echo "ERROR: -i/--input and -o/--output are required." >&2
    usage; exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "ERROR: input genome directory not found: $INPUT_DIR" >&2; exit 1
fi

if [[ ! -d "$DATABASE" ]]; then
    echo "ERROR: GTDB-Tk database directory not found: $DATABASE" >&2; exit 1
fi

# Count input genomes as a sanity check
shopt -s nullglob
GENOMES=( "${INPUT_DIR%/}"/*."${EXTENSION}" )
shopt -u nullglob
if [[ ${#GENOMES[@]} -eq 0 ]]; then
    echo "ERROR: no '*.${EXTENSION}' files found in: $INPUT_DIR" >&2
    echo "       (use -x/--extension if your genomes use a different suffix)" >&2
    exit 1
fi

# ---------- export DB path (required by gtdbtk) ----------------------------
export GTDBTK_DATA_PATH="$DATABASE"

# ---------- prepare output directory ---------------------------------------
mkdir -p "$(dirname "$OUT_DIR")"

# ---------- build & run command --------------------------------------------
cmd=( gtdbtk classify_wf
      --genome_dir "$INPUT_DIR"
      --out_dir    "$OUT_DIR"
      --cpus       "$CPUS"
      --extension  "$EXTENSION" )

[[ "$PLACE_SPECIES" -eq 1 ]] && cmd+=( --place_species )
[[ "$FORCE"         -eq 1 ]] && cmd+=( --force )
# shellcheck disable=SC2206
[[ -n "$EXTRA_ARGS" ]] && cmd+=( $EXTRA_ARGS )

echo "======================================================================"
echo "[$(date '+%F %T')] Running GTDB-Tk classify_wf"
echo "  Input:    $INPUT_DIR  (${#GENOMES[@]} genome(s) with .${EXTENSION})"
echo "  Output:   $OUT_DIR"
echo "  Database: $GTDBTK_DATA_PATH"
echo "  CPUs:     $CPUS"
echo "  Cmd:      ${cmd[*]}"
echo "======================================================================"

"${cmd[@]}"

echo "[$(date '+%F %T')] Done."