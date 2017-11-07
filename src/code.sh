#!/bin/bash

# -e = exit on error; -x = output each line that is executed to log; -o pipefail = throw an error if there's an error in pipeline
set -e -x -o pipefail

#Download inputs from DNAnexus in parallel, these will be downloaded to /home/dnanexus/in/
dx-download-all-inputs --parallel

#Extract required resources from assets folder into /home/dnanexus/
dx cat project-ByfFPz00jy1fk6PjpZ95F27J:file-F7k4g980777vqB04097vQkv0 | tar zxf - # ~/R-3.4.2_ggplot2.tar.gz -> ~/R-3.4.2/
dx cat project-ByfFPz00jy1fk6PjpZ95F27J:file-BxVGV9Q022qPQ5f2pbQYqbP4 | tar xf - # ~/hs37d5-fasta.tar -> ~/hs37d5.fa
dx cat project-ByfFPz00jy1fk6PjpZ95F27J:file-BxVGXBQ022qPfbkzbJQk87bp | tar xf - # ~/hs37d5-sdf.tar -> ~/hs37d5.sdf/
dx cat project-ByfFPz00jy1fk6PjpZ95F27J:file-BxVGJfj022q45ff2b0j8V73B | tar xf - # ~/stratification-bed-files-f35a0f7.tar -> ~/bed_files/

#Add R to path
export PATH='/home/dnanexus/R-3.4.2/bin:'$PATH

#The files-HG001.tsv file is a master file containing relative filepaths to all of the bed files used by hap.py for results stratifcation.
#files-HG001.tsv must in the parent directory of the bed_files/ directory for relative filepaths to be correct, so copy from /home/dnanexus/bed_files/ > /home/dnanexus/ 
cp ./bed_files/files-HG001.tsv ./files-HG001.tsv

#The app accept both uncompressed (.vcf) and gzipped (.vcf.gz) VCF files as input
#If files are compressed, they need to be decompressed.

if [[  $truth_vcf_path =~ \.gz$ ]]; then
	#If truth vcf is gzipped...	
	echo "ZIPPED truth VCF unzipping."
	#Unzip the vcf
	gzip -d $truth_vcf_path
	#Remove the .gz suffix from truth_vcf filepath
	truth_vcf_path=$(echo ${truth_vcf_path%.*})
else 
	echo "truth VCF not zipped"
fi

#Repeat above steps for the query_vcf
if [[  $query_vcf_path =~ \.gz$ ]]; then 
	#If query vcf is gzipped...		
	echo "ZIPPED query VCF unzipping."
	#Unzip the vcf
	gzip -d $query_vcf_path
	#Remove the .gz suffix from query_vcf filepath
	query_vcf_path=$(echo ${query_vcf_path%.*})
else 
	echo "query VCF not zipped"
fi

#Strip 'chr' from chromsome field of VCF and BED files
sed  -i 's/chr//' $truth_vcf_path $query_vcf_path $panel_bed_path $high_conf_bed_path

#Zip and index VCFs
bgzip $truth_vcf_path; tabix -p vcf ${truth_vcf_path}.gz
bgzip $query_vcf_path; tabix -p vcf ${query_vcf_path}.gz
#Following gzipping, append .gz to vcf filepath variables
truth_vcf_path=${truth_vcf_path}.gz
query_vcf_path=${query_vcf_path}.gz

#Run hap.py in docker container
#Mount /home/dnanexus/ to /data/
#For input files that are stored in /home/dnanexus/in/... replace '/home/dnanexus' with '/data' in filepath using: ${orig_filepath/home\/dnanexus/data} 
#If sample is flagged as NA12878, use HG001 stratification bed files (indexed in files-HG001.tsv) to provide additional stratification of results
if $na12878; then
     dx-docker run -v /home/dnanexus/:/data pkrusche/hap.py:v0.3.9 /opt/hap.py/bin/hap.py \
          -r /data/hs37d5.fa --stratification data/files-HG001.tsv --pass-only \
          --engine vcfeval -f ${high_conf_bed_path/home\/dnanexus/data} -T ${panel_bed_path/home\/dnanexus/data} \
          --ci-alpha 0.05 -o data/"$prefix" ${truth_vcf_path/home\/dnanexus/data} ${query_vcf_path/home\/dnanexus/data}
#Else if sample is not flagged as NA12878, run same command as above but without the stratification option
else
     dx-docker run -v /home/dnanexus/:/data pkrusche/hap.py:v0.3.9 /opt/hap.py/bin/hap.py \
          -r /data/hs37d5.fa --pass-only \
          --engine vcfeval -f ${high_conf_bed_path/home\/dnanexus/data} -T ${panel_bed_path/home\/dnanexus/data} \
          --ci-alpha 0.05 -o data/"$prefix" ${truth_vcf_path/home\/dnanexus/data} ${query_vcf_path/home\/dnanexus/data}
fi

#Run R script to generate ROC curves from hap.py output
#See following link for details and original script: https://github.com/Illumina/hap.py/blob/d51d111e494b561b37c66299daf5a6c65a8d2ca9/doc/microbench.md
#The name argument is used to define the label in the plot's key. Use the prefix to set the name, but if it is long shorten it and add ellipsis. This
#prevents the plot's key growing too wide and squashing the actual plot.
name=$prefix
char_limit=15
#if name over 15 charaters...
if [ ${#name} -gt $char_limit ]; then 
	#take first 15 characters of prefix then add ...
	name=${name:0:$char_limit}...
fi

#First command plots true positive rate vs false positive rate
Rscript rocplot_pdf.Rscript "$prefix".roc_tpr-fpr "$prefix":"$name"
#Second command uses -pr flad to plot precision vs recall 
Rscript rocplot_pdf.Rscript -pr "$prefix".roc_pre-rec "$prefix":"$name"

#Create csv file containing version numbers of resources and apps used.
echo "#Resource,Version" > "$prefix".version-log.csv
echo "GIAB(NA12878),v3.3.2" >> "$prefix".version-log.csv
echo "Reference,hs37d5" >> "$prefix".version-log.csv
echo "hap.py,v0.3.9(Docker)" >> "$prefix".version-log.csv
echo "R,v3.4.2" >> "$prefix".version-log.csv
echo "ggplot2,v2.2.1" >> "$prefix".version-log.csv
echo "tabix,v0.2.6-2" >> "$prefix".version-log.csv

#Make directories to hold outputs
mkdir /home/dnanexus/out
mkdir /home/dnanexus/out/summary_csv
mkdir /home/dnanexus/out/detailed_results
#Move outputs to correct directories for upload back to project
cp "$prefix".summary.csv /home/dnanexus/out/summary_csv/
tar zcvf /home/dnanexus/out/detailed_results/"$prefix".tar.gz "$prefix".*

#Upload outputs (from /home/dnanexus/out) to DNAnexus
dx-upload-all-outputs --parallel
