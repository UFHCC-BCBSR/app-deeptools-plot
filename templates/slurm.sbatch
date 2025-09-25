#!/bin/bash
#SBATCH --job-name={{PROJECT_ID}}_tornado
#SBATCH --output={{OUTPUT_DIR}}/{{PROJECT_ID}}_tornado_%j.out
#SBATCH --error={{OUTPUT_DIR}}/{{PROJECT_ID}}_tornado_%j.err
#SBATCH --cpus-per-task={{CPUS}}
#SBATCH --mem={{MEMORY}}
#SBATCH --time={{TIME}}
#SBATCH --partition={{PARTITION}}
#SBATCH --account={{ACCOUNT}}
{{QOS_LINE}}
{{EMAIL_LINES}}

# Load required modules
module load deeptools

# Set variables
PROJECT_ID="{{PROJECT_ID}}"
OUTPUT_DIR="{{OUTPUT_DIR}}"
REGIONS_FILE="{{REGIONS_FILE}}"
BIGWIG_FILES=({{BIGWIG_FILES}})
CHUNK_SIZE={{CHUNK_SIZE}}
THREADS={{CPUS}}

# Create output directory
mkdir -p $OUTPUT_DIR
cd $OUTPUT_DIR

# Generate random suffix to avoid conflicts
RND=$RANDOM

echo "Starting analysis: $PROJECT_ID"
echo "Splitting regions file into chunks of $CHUNK_SIZE..."

# Split regions file into chunks
split -l $CHUNK_SIZE $REGIONS_FILE ${PROJECT_ID}.chunks${RND}.

# Rename chunks and fix bed format
for chunk in ${PROJECT_ID}.chunks${RND}.*; do
    name=$(basename $chunk)
    name=${name##*.}
    # Ensure proper BED format and unique names in column 4
    awk -v name=$name 'BEGIN {FS = "\t"; OFS = "\t"} {
        if(NF >= 3) {
            if(NF >= 4 && $4 != "") {
                print $1,$2,$3,$4"_"name,$5,$6
            } else {
                print $1,$2,$3,name"_"NR,$5,$6
            }
        }
    }' $chunk > tmp.$RND && mv tmp.$RND $chunk
done

echo "Processing $(ls ${PROJECT_ID}.chunks${RND}.* | wc -l) chunks..."

# Process each chunk
for chunk in ${PROJECT_ID}.chunks${RND}.*; do
    echo "Processing chunk: $chunk"
    computeMatrix reference-point \
        --referencePoint {{REFERENCE_POINT}} \
        -R $chunk \
        -S "${BIGWIG_FILES[@]}" \
        -b {{BEFORE_REGION}} -a {{AFTER_REGION}} \
        {{SKIP_ZEROS}} {{MISSING_DATA_AS_ZERO}} \
        --numberOfProcessors $THREADS \
        --outFileName ${chunk}.matrix.gz
done

echo "Merging matrices..."

# Merge all chunk matrices
computeMatrixOperations rbind \
    -m ${PROJECT_ID}.chunks${RND}.*.matrix.gz \
    -o ${PROJECT_ID}_matrix.gz

echo "Cleaning up chunk files..."
rm ${PROJECT_ID}.chunks${RND}.*

echo "Generating heatmap..."

# Generate heatmap
plotHeatmap \
    -m ${PROJECT_ID}_matrix.gz \
    -o ${PROJECT_ID}_heatmap.png \
    --heatmapWidth {{HEATMAP_WIDTH}} \
    --samplesLabel {{SAMPLE_LABELS}} \
    --xAxisLabel "{{X_AXIS_LABEL}}" \
    --yAxisLabel "{{Y_AXIS_LABEL}}" \
    --regionsLabel "{{REGIONS_LABEL}}" \
    --colorList "{{COLOR_LIST}}" \
    --sortUsing {{SORT_USING}} \
    --yMin {{Y_MIN}} \
    --yMax {{Y_MAX}} \
    --outFileSortedRegions ${PROJECT_ID}_sorted.bed

echo "Analysis complete!"
