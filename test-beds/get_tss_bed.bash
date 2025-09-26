# Download GENCODE hg38 GTF
wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_44/gencode.v44.annotation.gtf.gz

# Convert to TSS BED (extract TSS from genes)
zcat gencode.v44.annotation.gtf.gz | \
awk '$3=="gene"' | \
awk 'BEGIN{OFS="\t"} {
    split($10, gene_id, "\""); 
    split($14, gene_name, "\""); 
    if($7=="+") {tss=$4-1} else {tss=$5-1}; 
    print $1, tss, tss+1, gene_name[2], ".", $7
}' > hg38.genes.tss.bed
