#!/bin/bash

set -e -x -o pipefail

dx-download-all-inputs --parallel

#Move inputs into 'work' folder and create symbolic links
mkdir /work
cd /work
export HOME=/work
mv /home/dnanexus/in in
ln -sf /work/in /home/dnanexus/in

#Extract software from assets folder
#dx cat $DX_PROJECT_CONTEXT_ID:/assets/hap.py-HAP-207.tar.gz | tar -C / -zxf -
dx cat $DX_PROJECT_CONTEXT_ID:/assets/hs37d5-fasta.tar | tar xf -
dx cat $DX_PROJECT_CONTEXT_ID:/assets/hs37d5-sdf.tar | tar xf -
#dx cat $DX_PROJECT_CONTEXT_ID:/assets/pysam-0.9.1-pandas-0.18.1-numpy-1.11.0-Cython-0.24.tar.gz | tar zxf -
#dx cat $DX_PROJECT_CONTEXT_ID:/assets/rtg-tools-3.6-dev-2365fac.tar.gz | tar zxf -
dx cat $DX_PROJECT_CONTEXT_ID:/assets/stratification-bed-files-f35a0f7.tar | tar xf -

cp ./bed_files/files-HG001.tsv ./files-HG001.tsv
#Create symbolic link for hap.py
#ln -s /opt/hap.py-HAP-207 hap.py

#Set HGREF environment variable (used by hap.py)
#export HGREF=$HOME/hs37d5.fa

#Unzip zipped VCF files
truth_vcf=$truth_vcf_path
if [[  $truth_vcf =~ \.gz$ ]]; then 
	truth_vcf=$(echo ${truth_vcf_path%.*})
	echo "ZIPPED truth VCF unzipping."
	gzip -d $truth_vcf_path
else 
	echo "truth VCF not zipped"
fi
echo $truth_vcf

query_vcf=$query_vcf_path
if [[  $query_vcf =~ \.gz$ ]]; then 
	query_vcf=$(echo ${query_vcf_path%.*})
	echo "ZIPPED query VCF unzipping."
	gzip -d $query_vcf_path
else 
	echo "query VCF not zipped"
fi
echo $query_vcf

#Strip 'chr' from chromsome field of VCF and BED files
sed  -i 's/chr//' $truth_vcf $query_vcf $panel_bed_path $high_conf_bed_path

#Zip and index VCFs
bgzip $truth_vcf; tabix -p vcf ${truth_vcf}.gz
bgzip $query_vcf; tabix -p vcf ${query_vcf}.gz

#Create intersect BED
bedtools intersect -a $panel_bed_path -b $high_conf_bed_path > intersect.bed

#Create filepath for docker enviroment (replace '/home/dnanexus' with '/data')
truth_vcf_docker=$(echo $truth_vcf | sed -e "s/home\/dnanexus/data/g")
query_vcf_docker=$(echo $query_vcf | sed -e "s/home\/dnanexus/data/g")

#Run hap.py; if sample is NA12878, use HG001 stratification file
if $na12878; then
     dx-docker run -v /work/:/data pkrusche/hap.py:v0.3.9 /opt/hap.py/bin/hap.py \
          -r /data/hs37d5.fa --stratification data/files-HG001.tsv --pass-only \
          --engine vcfeval -f data/intersect.bed -o data/"$prefix" ${truth_vcf_docker}.gz ${query_vcf_docker}.gz
else
     dx-docker run -v /work/:/data pkrusche/hap.py:v0.3.9 /opt/hap.py/bin/hap.py \
          -r /data/hs37d5.fa --pass-only \
          --engine vcfeval -f data/intersect.bed -o data/"$prefix" ${truth_vcf_docker}.gz ${query_vcf_docker}.gz
fi

#Process outputs
mkdir /home/dnanexus/out
mkdir /home/dnanexus/out/summary_csv
mkdir /home/dnanexus/out/detailed_results
cp "$prefix".summary.csv /home/dnanexus/out/summary_csv/
tar zcvf /home/dnanexus/out/detailed_results/"$prefix".tar.gz "$prefix".*

HOME=/home/dnanexus
dx-upload-all-outputs --parallel
