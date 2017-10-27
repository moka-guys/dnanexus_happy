#!/bin/bash

set -e -x -o pipefail

#Download inputs from DNAnexus in parallel, these will be downloaded to /home/dnanexus/in/
dx-download-all-inputs --parallel

#Extract software from assets folder into /home/dnanexus/
dx cat $DX_PROJECT_CONTEXT_ID:/assets/hs37d5-fasta.tar | tar xf -
dx cat $DX_PROJECT_CONTEXT_ID:/assets/hs37d5-sdf.tar | tar xf -
dx cat $DX_PROJECT_CONTEXT_ID:/assets/stratification-bed-files-f35a0f7.tar | tar xf -

#The files-HG001.tsv file is a master file containing relative filepaths to all of the bed files used by hap.py for results stratifcation.
#files-HG001.tsv must in the parent directory of the bed_files/ directory for relative filepaths to be correct, so copy from /home/dnanexus/bed_files/ > /home/dnanexus/ 
cp ./bed_files/files-HG001.tsv ./files-HG001.tsv

#The app accept both uncompressed (.vcf) and gzipped (.vcf.gz) VCF files as input
#If files are compressed, they need to be decompressed.

#Set truth_vcf variable to be the path of the input truth vcf.
truth_vcf=$truth_vcf_path

if [[  $truth_vcf =~ \.gz$ ]]; then
	#If truth vcf is gzipped...	
	echo "ZIPPED truth VCF unzipping."
	#Unzip the vcf
	gzip -d $truth_vcf_path
	#Remove the .gz suffix from truth_vcf filepath
	truth_vcf=$(echo ${truth_vcf_path%.*})
else 
	echo "truth VCF not zipped"
fi
echo $truth_vcf

#Repeat above steps for the query_vcf
#Set query_vcf variable to be the path of the input query vcf.
query_vcf=$query_vcf_path

if [[  $query_vcf =~ \.gz$ ]]; then 
	#If query vcf is gzipped...		
	echo "ZIPPED query VCF unzipping."
	#Unzip the vcf
	gzip -d $query_vcf_path
	#Remove the .gz suffix from query_vcf filepath
	query_vcf=$(echo ${query_vcf_path%.*})
else 
	echo "query VCF not zipped"
fi
echo $query_vcf

#Strip 'chr' from chromsome field of VCF and BED files
sed  -i 's/chr//' $truth_vcf $query_vcf $panel_bed_path $high_conf_bed_path

#Zip and index VCFs
bgzip $truth_vcf; tabix -p vcf ${truth_vcf}.gz
bgzip $query_vcf; tabix -p vcf ${query_vcf}.gz

#Create filepaths for docker enviroment (replace '/home/dnanexus' with '/data')
truth_vcf_docker=$(echo $truth_vcf | sed -e "s/home\/dnanexus/data/g")
query_vcf_docker=$(echo $query_vcf | sed -e "s/home\/dnanexus/data/g")
high_conf_bed_docker=$(echo $high_conf_bed_path | sed -e "s/home\/dnanexus/data/g")
panel_bed_docker=$(echo $panel_bed_path | sed -e "s/home\/dnanexus/data/g")

#Run hap.py in docker container
#Mount /home/dnanexus/ to /data/
#If sample is NA12878, use HG001 stratification file
if $na12878; then
     dx-docker run -v /home/dnanexus/:/data pkrusche/hap.py:v0.3.9 /opt/hap.py/bin/hap.py \
          -r /data/hs37d5.fa --stratification data/files-HG001.tsv --pass-only \
          --engine vcfeval -f ${high_conf_bed_docker} -T ${panel_bed_docker} -o data/"$prefix" ${truth_vcf_docker}.gz ${query_vcf_docker}.gz
else
     dx-docker run -v /home/dnanexus/:/data pkrusche/hap.py:v0.3.9 /opt/hap.py/bin/hap.py \
          -r /data/hs37d5.fa --pass-only \
          --engine vcfeval -f ${high_conf_bed_docker} -T ${panel_bed_docker} -o data/"$prefix" ${truth_vcf_docker}.gz ${query_vcf_docker}.gz
fi

#Make directories to hold outputs
mkdir /home/dnanexus/out
mkdir /home/dnanexus/out/summary_csv
mkdir /home/dnanexus/out/detailed_results
#Move outputs to correct directories for upload back to project
cp "$prefix".summary.csv /home/dnanexus/out/summary_csv/
tar zcvf /home/dnanexus/out/detailed_results/"$prefix".tar.gz "$prefix".*

#Upload outputs (from /home/dnanexus/out) to DNAnexus
dx-upload-all-outputs --parallel
