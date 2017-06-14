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
dx cat $DX_PROJECT_CONTEXT_ID:/assets/hap.py-HAP-207.tar.gz | tar -C / -zxf -
dx cat $DX_PROJECT_CONTEXT_ID:/assets/hs37d5-fasta.tar | tar xf -
dx cat $DX_PROJECT_CONTEXT_ID:/assets/hs37d5-sdf.tar | tar xf -
dx cat $DX_PROJECT_CONTEXT_ID:/assets/pysam-0.9.1-pandas-0.18.1-numpy-1.11.0-Cython-0.24.tar.gz | tar zxf -
dx cat $DX_PROJECT_CONTEXT_ID:/assets/rtg-tools-3.6-dev-2365fac.tar.gz | tar zxf -
dx cat $DX_PROJECT_CONTEXT_ID:/assets/stratification-bed-files-f35a0f7.tar | tar xf -

#Create symbolic link for hap.py
ln -s /opt/hap.py-HAP-207 hap.py

#Set HGREF environment variable (used by hap.py)
export HGREF=$HOME/hs37d5.fa

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

#Run hap.py; if sample is NA12878, use HG001 stratification file
if $na12878; then
	./hap.py/bin/hap.py --no-fixchr-truth --no-fixchr-query --pass-only --no-auto-index \
                    -r ./hs37d5.fa \
                    --stratification ./bed_files/files-HG001.tsv \
                    --engine vcfeval --engine-vcfeval-path ./rtg/rtg --engine-vcfeval-template ./hs37d5.sdf/ \
                    -f ./intersect.bed \
                    -o "$prefix" \
                    ${truth_vcf}.gz ${query_vcf}.gz
else
	./hap.py/bin/hap.py --no-fixchr-truth --no-fixchr-query --pass-only --no-auto-index \
                    -r ./hs37d5.fa \
                    --engine vcfeval --engine-vcfeval-path ./rtg/rtg --engine-vcfeval-template ./hs37d5.sdf/ \
                    -f ./intersect.bed \
                    -o "$prefix" \
                    ${truth_vcf}.gz ${query_vcf}.gz
fi

#Process outputs
mkdir /home/dnanexus/out
mkdir /home/dnanexus/out/summary_csv
mkdir /home/dnanexus/out/detailed_results
cp "$prefix".summary.csv /home/dnanexus/out/summary_csv/
tar zcvf /home/dnanexus/out/detailed_results/"$prefix".tar.gz "$prefix".*

HOME=/home/dnanexus
dx-upload-all-outputs --parallel
