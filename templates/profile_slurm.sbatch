#!/bin/bash
#SBATCH --job-name={{PROJECT_ID}}_profile
#SBATCH --output={{OUTPUT_DIR}}/logs/{{PROJECT_ID}}_profile_%j.out
#SBATCH --error={{OUTPUT_DIR}}/logs/{{PROJECT_ID}}_profile_%j.err
#SBATCH --cpus-per-task={{CPUS}}
#SBATCH --mem={{MEMORY}}
#SBATCH --time={{TIME}}
#SBATCH --partition={{PARTITION}}
#SBATCH --account={{ACCOUNT}}
{{QOS_LINE}}
{{EMAIL_LINES}}

# Initialize module system
source /etc/profile.d/modules.sh

# Load required modules
module purge
module load deeptools

# Optional: Debug check
which computeMatrix
which plotHeatmap

# Set variables
PROJECT_ID="{{PROJECT_ID}}"
OUTPUT_DIR="{{OUTPUT_DIR}}"
REGIONS_FILE="{{REGIONS_FILE}}"
BIGWIG_FILES=({{BIGWIG_FILES}})
CHUNK_SIZE={{CHUNK_SIZE}}
THREADS={{CPUS}}
Y_MIN={{Y_MIN}}
Y_MAX={{Y_MAX}}
X_LABEL="{{X_AXIS_LABEL_PROFILE}}"
Y_LABEL="{{Y_AXIS_LABEL_PROFILE}}"
PLOT_WIDTH={{PLOT_WIDTH}}
PLOT_HEIGHT={{PLOT_HEIGHT}}

# Create output directory and logs directory
mkdir -p $OUTPUT_DIR/logs
cd $OUTPUT_DIR

# Check if matrix already exists
MATRIX_FILE="${PROJECT_ID}_matrix.gz"
REUSE_MATRIX=false

if [[ -f "$MATRIX_FILE" ]]; then
    echo "Found existing matrix file: $MATRIX_FILE"
    echo "Matrix file size: $(ls -lh $MATRIX_FILE | awk '{print $5}')"
    echo "Matrix file date: $(ls -l $MATRIX_FILE | awk '{print $6, $7, $8}')"
    echo "Reusing existing matrix, skipping computeMatrix step..."
    REUSE_MATRIX=true
else
    echo "No existing matrix found, will compute new matrix..."
    REUSE_MATRIX=false
fi

# Only compute matrix if it doesn't exist
if [[ "$REUSE_MATRIX" == false ]]; then
    # Generate random suffix to avoid conflicts
    RND=$RANDOM
    echo "Starting matrix computation for: $PROJECT_ID"
    echo "Y-axis range: $Y_MIN to $Y_MAX"
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
    
    echo "Processing $(ls ${PROJECT_ID}.chunks${RND}.* | wc -l) chunks in parallel..."
    
    # Process chunks in parallel
    chunk_count=0
    max_parallel=4
    threads_per_job=$((THREADS/max_parallel))
    
    for chunk in ${PROJECT_ID}.chunks${RND}.*; do
        echo "Processing chunk: $chunk (using $threads_per_job threads)"
        computeMatrix reference-point \
            --referencePoint {{REFERENCE_POINT}} \
            -R $chunk \
            -S "${BIGWIG_FILES[@]}" \
            -b {{BEFORE_REGION}} -a {{AFTER_REGION}} \
            {{SKIP_ZEROS}} {{MISSING_DATA_AS_ZERO}} \
            -p $threads_per_job \
            --outFileName ${chunk}.matrix.gz &
        ((chunk_count++))
        
        # Wait if we've reached max parallel jobs
        if (( chunk_count % max_parallel == 0 )); then
            echo "Waiting for batch of $max_parallel jobs to complete..."
            wait
        fi
    done
    
    # Wait for remaining jobs
    echo "Waiting for final jobs to complete..."
    wait
    
    echo "Merging matrices..."
    # Merge all chunk matrices
    computeMatrixOperations rbind \
        -m ${PROJECT_ID}.chunks${RND}.*.matrix.gz \
        -o ${PROJECT_ID}_matrix.gz
    
    echo "Cleaning up chunk files..."
    rm ${PROJECT_ID}.chunks${RND}.*
else
    echo "Skipping matrix computation - using existing matrix file"
fi

# Generate timestamp suffix for profile plot
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Determine output filename
if [[ "$REUSE_MATRIX" == true ]]; then
    PROFILE_OUTPUT="${PROJECT_ID}_colored_overlay_${TIMESTAMP}.png"
    echo "Creating new profile plot (reusing matrix): $PROFILE_OUTPUT"
else
    PROFILE_OUTPUT="${PROJECT_ID}_colored_overlay.png"
    echo "Creating profile plot: $PROFILE_OUTPUT"
fi

# Create colored profile plot  
echo "Creating colored profile plot..."
plotProfile \
    -m ${PROJECT_ID}_matrix.gz \
    --perGroup \
    -o $PROFILE_OUTPUT \
    --samplesLabel {{SAMPLE_LABELS_OVERLAY}} \
    --colors {{SAMPLE_COLORS_OVERLAY}} \
    --plotTitle "Grouped Profile Plot" \
    --plotWidth $PLOT_WIDTH \
    --plotHeight $PLOT_HEIGHT \
    --yAxisLabel "$Y_LABEL" \
    --yMin $Y_MIN \
    --yMax $Y_MAX

echo "Profile analysis complete!"
echo "Matrix reused: $REUSE_MATRIX"
echo "Output files:"
ls -la ${PROJECT_ID}*.png ${PROJECT_ID}*.gz