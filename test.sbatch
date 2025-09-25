#!/bin/bash
#SBATCH --job-name=manual_tornado
#SBATCH --output=logs/test.out
#SBATCH --error=logs/test.err
#SBATCH --cpus-per-task=16
#SBATCH --mem=150GB
#SBATCH --time=48:00:00
#SBATCH --account=cancercenter-dept
#SBATCH --qos=cancercenter-dept-b

# Load required modules
module load deeptools

# Set script to exit on error
set -e

# Define variables
PROJECT_ID="my-test"
OUT_DIR="/blue/cancercenter-dept/hkates/Apps/torando-plotter/output/my-test"
#REGIONS_FILE="/blue/cancercenter-dept/hkates/Projects_2025_Feb-May/Clanton/Male/OUTPUT/genome/genes.tss.bed"
REGIONS_FILE="/blue/cancercenter-dept/hkates/Apps/torando-plotter/test_genes_12k.bed"
CHUNK_SIZE=5000
THREADS=16

# BigWig files array
BIGWIG_FILES=("/blue/cancercenter-dept/privapps/data/atac/clanton/NS4167_Male_GoodSamples/Control_REP1.mLb.clN.bigWig" "/blue/cancercenter-dept/privapps/data/atac/clanton/NS4167_Male_GoodSamples/Control_REP2.mLb.clN.bigWig" "/blue/cancercenter-dept/privapps/data/atac/clanton/NS4167_Male_GoodSamples/Control_REP3.mLb.clN.bigWig" "/blue/cancercenter-dept/privapps/data/atac/clanton/NS4167_Male_GoodSamples/Heat_REP1.mLb.clN.bigWig" "/blue/cancercenter-dept/privapps/data/atac/clanton/NS4167_Male_GoodSamples/Heat_REP2.mLb.clN.bigWig" "/blue/cancercenter-dept/privapps/data/atac/clanton/NS4167_Male_GoodSamples/Heat_REP3.mLb.clN.bigWig" "/blue/cancercenter-dept/privapps/data/atac/clanton/NS4167_Male_GoodSamples/Heat_REP4.mLb.clN.bigWig")

# Create output directory
mkdir -p $OUT_DIR
cd $OUT_DIR

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
        --referencePoint TSS \
        -b 2000 -a 2000 \
        -R $chunk \
        -S "${BIGWIG_FILES[@]}" \
        --skipZeros \
        --missingDataAsZero \
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
    --heatmapWidth 6 \
    --samplesLabel "Control_REP1" "Control_REP2" "Control_REP3" "Heat_REP1" "Heat_REP2" "Heat_REP3" "Heat_REP4" \
    --xAxisLabel "distance (bp)" \
    --refPointLabel "TSS" \
    --yAxisLabel "Genes" \
    --regionsLabel "ATAC" \
    --colorList "white,red" \
    --sortUsing mean \
    --outFileSortedRegions ${PROJECT_ID}_sorted.bed

echo "Analysis complete!"
echo "Files created:"
ls -lh ${PROJECT_ID}_matrix.gz ${PROJECT_ID}_heatmap.png ${PROJECT_ID}_sorted.bed
