# Utility Scripts

Helper scripts for preprocessing data before using the deeptools plotting app.

## merge-bigwigs-by-group.sbatch

Merge multiple bigWig files by group in parallel using SLURM array jobs.

**Usage:**
1. Edit the "USER CONFIGURATION" section in the script
2. Count your groups: `tail -n +2 sample-info.csv | cut -d',' -f2 | sort -u | wc -l`
3. Update `--array=0-N` where N is (group_count - 1)
4. Submit: `sbatch utils/merge-bigwigs-by-group.sbatch`
5. After completion, add header: `sed -i '1i\sample,group,color,sample_label' output/merged-sample-info.csv`

**Example:**
For 6 groups, use `--array=0-5`

## merge-two-bigwigs.sbatch

Merge two already-merged bigWigs (faster than re-merging all original samples).
