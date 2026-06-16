#!/bin/bash
#SBATCH --job-name=fastpQC                                       # name shown in squeue. It can be anything.
#SBATCH --output=/maps/projects/course_1/scratch/group6/group-project-group-6/week18-preprocessing/logs/%x_%j.out   # stdout log. Make sure to create your logs folder
#SBATCH --error=/maps/projects/course_1/scratch/group6/group-project-group-6/week18-preprocessing/logs/%x_%j.err    # stderr log
#SBATCH --ntasks=1                                               # one task (one process group)
#SBATCH --cpus-per-task=10                                       # CPUs available to that task
#SBATCH --mem-per-cpu=10G                                        # RAM per CPU (total = cpus * mem-per-cpu)
#SBATCH --time=03:00:00                                          # HH:MM:SS wall-clock limit
#SBATCH --mail-type=end                                          # email me when it finishes
#SBATCH --mail-type=fail                                         # email me if it fails
#SBATCH --mail-user=zxn328@alumni.ku.dk                        # your KU email
#SBATCH --reservation=NBIB25004U                                 # class reservation. Specific for this course. Bent reserved a node for us.
#SBATCH --account=teaching                                       # class billing account


# =============================================================================
# SRA Download & Extraction Script for Metagenomics Class
# -----------------------------------------------------------------------------
# Downloads a sequencing run from NCBI's SRA, validates its integrity,
# and extracts the reads into FASTQ format.
#
# Requirements: sra-tools (prefetch, vdb-validate, fasterq-dump) installed
#               and configured (run `vdb-config --interactive` once beforehand).
#
# Usage:
#   ./download_sra.sh -a <RUN_ACCESSION> [-t THREADS] [-o OUTPUT_DIR]
#
# Flags:
#   -a  (required) SRA run accession, e.g. SRR513791
#   -t  (optional) number of CPU threads for fasterq-dump   [default: 8]
#   -o  (required) directory where prefetch will place data
#   -h             show this help message
#
# Examples:
#   ./download_sra.sh -a SRR513791
#   ./download_sra.sh -a SRR513791 -t 20
#   ./download_sra.sh -a SRR513791 -t 20 -o /data/metagenomics
# =============================================================================

# ---- 0. Load required modules -----------------------------------------------
module load sratoolkit

# ---- 1. Default values ------------------------------------------------------
# These are used if the user doesn't override them via flags.
ACCESSION=""
THREADS=8
OUTPUT_DIR=""

# ---- 2. Helper: print usage and exit ---------------------------------------
usage() {
    echo "Usage: $0 -a <RUN_ACCESSION> [-t THREADS] [-o OUTPUT_DIR]"
    echo ""
    echo "  -a  SRA run accession (required), e.g. SRR513791"
    echo "  -t  number of threads for fasterq-dump (default: 8)"
    echo "  -o  output directory (required)"
    echo "  -h  show this help message"
    exit 1
}

# ---- 3. Parse command-line flags -------------------------------------------
# `getopts` reads the flags in any order. The ":" after a letter means that
# flag expects a value (e.g. -a SRR513791). A leading ":" in the optstring
# enables silent error handling so we can print our own messages.
while getopts ":a:t:o:h" opt; do
    case "${opt}" in
        a) ACCESSION="${OPTARG}" ;;   # run accession
        t) THREADS="${OPTARG}"   ;;   # number of threads
        o) OUTPUT_DIR="${OPTARG}" ;;  # output directory
        h) usage ;;                   # help
        \?) echo "Invalid option: -${OPTARG}" >&2; usage ;;
        :)  echo "Option -${OPTARG} requires an argument." >&2; usage ;;
    esac
done

# ---- 4. Validate required inputs -------------------------------------------
# The accession is mandatory; everything else has a default.
if [ -z "${ACCESSION}" ]; then
    echo "Error: -a <RUN_ACCESSION> is required."
    echo "Error: -o <output_directory> is required."
    usage
fi

# Exit immediately if any command fails, so we don't continue on a bad download.
set -e

# Make sure the output directory exists (prefetch won't create parent dirs).
mkdir -p "${OUTPUT_DIR}"

echo "=============================================="
echo "Accession : ${ACCESSION}"
echo "Threads   : ${THREADS}"
echo "Output dir: ${OUTPUT_DIR}"
echo "=============================================="

# ---- 5. Download the .sra file ---------------------------------------------
# `prefetch` downloads the raw SRA archive into OUTPUT_DIR. It creates a
# subfolder named after the accession, e.g. <OUTPUT_DIR>/SRR513791/SRR513791.sra
#   --max-size 1t : allow files up to 1 terabyte (metagenomes can be huge)
#   -p            : show a progress bar
#   -O            : output location
echo "[1/3] Downloading ${ACCESSION} with prefetch..."
prefetch "${ACCESSION}" --max-size 1t -p -O "${OUTPUT_DIR}"

# Path to the downloaded .sra file and its containing folder.
# The validation log will live next to the .sra file.
ACC_DIR="${OUTPUT_DIR%/}/${ACCESSION}"
SRA_FILE="${ACC_DIR}/${ACCESSION}.sra"
VALIDATION_LOG="${ACC_DIR}/${ACCESSION}_validation.txt"

# ---- 6. Validate the downloaded file ---------------------------------------
# `vdb-validate` checks the integrity of the .sra archive (checksums,
# internal structure). Both stdout and stderr (2>&1) are captured into a
# text file stored in the same directory as the .sra file.
echo "[2/3] Validating ${SRA_FILE}..."
vdb-validate "${SRA_FILE}" > "${VALIDATION_LOG}" 2>&1

echo "Validation results saved to: ${VALIDATION_LOG}"
cat "${VALIDATION_LOG}"

# ---- 7. Extract reads into FASTQ format ------------------------------------
# `fasterq-dump` converts the .sra archive into FASTQ file(s).
# Paired-end runs will produce _1.fastq and _2.fastq automatically.
#   -e : number of threads (from the -t flag or default)
#   -O : output directory (same folder that holds the .sra)
#   -p : show progress
echo "[3/3] Extracting FASTQ from ${SRA_FILE} using ${THREADS} threads..."
fasterq-dump "${SRA_FILE}" -e "${THREADS}" -O "${ACC_DIR}" -p

echo "=============================================="
echo "Done! FASTQ files are in ${ACC_DIR}/"
echo "Validation log: ${VALIDATION_LOG}"
echo "=============================================="
