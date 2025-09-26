# DeepTools Analysis Generator

A Shiny application for generating heatmaps and profile plots from BigWig files using DeepTools on HiPerGator.

## Setup and Running

### Prerequisites
- Access to HiPerGator
- R/RStudio Server session on HiPerGator
- Access to a blue storage group directory

### Installation and Startup

1. \*\*Clone the repository\*\* to your HiPerGator directory:
   \`\`\`bash
   git clone <repository-url>
   cd deeptools-analysis-generator
   \`\`\`

2. \*\*Start an RStudio Server session\*\* on HiPerGator:
   - Log into HiPerGator
   - Request an interactive session or submit a job with:
   - Load R: \`module load R/4.5\`
   - \`rserver\`
   - In Rstudio, navigate to your app directory

3. \*\*Run the application\*\*:
   \`\`\`r
   # Install required packages if needed
   install.packages(c("shiny", "shinydashboard", "shinyFiles", "shinyjs", "DT", "processx", "jsonlite"))
   
   # Run the app
   shiny::runApp("app.R")
   \`\`\`

## Usage

### Connect
- Enter your HiPerGator group name (e.g., \`cancercenter-dept\`)
- This allows browsing of \`/blue/your-group/\` directories for file selection

### Required Files

#### BigWig Files
- Select multiple BigWig files for analysis
- Files should be normalized (e.g., RPM/CPM scaled)

#### Regions File (BED format)
- BED file containing genomic regions of interest
- Used to define where to calculate signal (e.g., TSS regions, peaks)

#### Sample Information File (CSV) - Required for Profile Plots
\*\*Required columns:\*\*
- \`sample\`: Sample identifier that must match part of BigWig filename
- \`group\`: Group/condition for the sample
- \`color\`: Color for plotting (e.g., "blue", "red", "lightblue")

\*\*Optional columns:\*\*
- \`sample_label\`: Custom labels for plot display (if not provided, uses \`sample\` column)

\*\*Example CSV:\*\*
\`\`\`csv
sample,group,color,sample_label
RM1-064-T3_REP1,Treatment_d3,blue,Treated_d3
RM1-082-T3_REP1,Treatment_d3,blue,Treated_d3
RM1-048-T1_REP1,Control_d1,red,Control_d1
\`\`\`

### Parameter Management

#### Saving Parameters
- Click "Save Parameters" to download a JSON file with all current settings
- Use descriptive filenames to organize different analysis configurations

#### Loading Parameters
- Use "Load Saved Parameters" to restore a previous configuration
- All form fields will be populated with saved values
- File selections are restored if files still exist at original paths

### Analysis Types

#### Heatmap
- Individual signal tracks for each region
- Customizable sample labels, colors, sorting options
- Outputs: \`*_matrix.gz\`, \`*_heatmap.png\`, \`*_sorted.bed\`

#### Profile Plot
- Mean signal across all regions
- Requires sample information CSV
- Groups samples by color for overlay plotting
- Outputs: \`*_matrix.gz\`, \`*_colored_overlay.png\`

### Matrix Reuse Feature

\*\*Important\*\*: If you use the \*\*same Project ID\*\* for multiple runs:
- The app will detect existing \`{PROJECT_ID}_matrix.gz\` files
- \*\*computeMatrix step will be skipped\*\* (saves significant computation time)
- New plots will be generated with timestamp suffixes
- Use this feature to:
  - Experiment with different plot parameters
  - Generate multiple versions with different color schemes
  - Adjust plot dimensions or labels

### Manual Script Editing

After running an analysis:
1. Find \`profile_analysis.sbatch\` (or \`heatmap_analysis.sbatch\`) in your output directory
2. The script can be manually edited and re-submitted:
   \`\`\`bash
   # Edit the script as needed
   nano /path/to/output/profile_analysis.sbatch
   
   # Re-submit the job
   sbatch /path/to/output/profile_analysis.sbatch
   \`\`\`
3. The script will \*\*automatically skip computeMatrix\*\* if the matrix file already exists
4. Useful for fine-tuning parameters not available in the web interface

### Job Submission

The app submits SLURM jobs to HiPerGator:
- Jobs run in the background after submission
- Check job status with: \`squeue -u $USER\`
- Job logs are saved in \`{OUTPUT_DIR}/logs/\`
- Email notifications (if provided) will alert you when jobs complete

### Output Files

All outputs are saved to: \`{OUTPUT_DIR}/{PROJECT_ID}/\`

\*\*Profile Plot outputs:\*\*
- \`{PROJECT_ID}_matrix.gz\`: Computed matrix (reused for subsequent runs)
- \`{PROJECT_ID}_colored_overlay.png\`: Profile plot
- \`profile_analysis.sbatch\`: Submitted job script

\*\*Heatmap outputs:\*\*
- \`{PROJECT_ID}_matrix.gz\`: Computed matrix
- \`{PROJECT_ID}_heatmap.png\`: Heatmap image  
- \`{PROJECT_ID}_sorted.bed\`: Regions sorted by signal
- \`heatmap_analysis.sbatch\`: Submitted job script

## Troubleshooting

### Common Issues
- \*\*"No BigWig files matched"\*\*: Check that sample names in CSV partially match BigWig filenames
- \*\*"Colors too small" error\*\*: Ensure each sample has a color assigned in the CSV
- \*\*Authentication fails\*\*: Verify group name and password, check \`/blue/group-name/\` exists
- \*\*Job submission fails\*\*: Check SLURM account name matches your group allocation

### File Matching
The app matches BigWig files to samples using \*\*partial filename matching\*\*:
- Sample \`RM1-064-T3_REP1\` will match \`RM1-064-T3_REP1.mLb.clN.bigWig\`
- Use consistent naming between your CSV and BigWig files

## Tips
- Start with a small regions file to test parameters before full analysis
- Use parameter save/load for reproducible analyses
- Keep Project IDs consistent when iterating on plot appearance
- Monitor job progress in the HiPerGator job queue
