#!/bin/bash

# -e = exit on error; -x = output each line that is executed to log; -o pipefail = throw an error if there's an error in pipeline
set -e -x -o pipefail
if [[ $skip == false ]]; then
	#Download inputs from DNAnexus in parallel, these will be downloaded to /home/dnanexus/in/
	dx-download-all-inputs --parallel

	echo >&2 "/ngenome_reference=${genome_reference}"
	echo >&2 "truth_vcf_path=${truth_vcf_path}"
	echo >&2 "query_vcf_path=${query_vcf_path}"
	echo >&2 "high_conf_bed_path=${high_conf_bed_path}"
	echo >&2 "panel_bed_path=${panel_bed_path}"

	if [[  $genome_reference == "GRCh37" ]]; then
		echo "Using build GRCh37 as genome reference."
		#Extract GRCh37 required resources from assets folder into /home/dnanexus/
		dx cat project-ByfFPz00jy1fk6PjpZ95F27J:file-BxVGV9Q022qPQ5f2pbQYqbP4 | tar xf - # ~/hs37d5-fasta.tar -> ~/hs37d5.fa
		dx cat project-ByfFPz00jy1fk6PjpZ95F27J:file-BxVGXBQ022qPfbkzbJQk87bp | tar xf - # ~/hs37d5-sdf.tar -> ~/S$d862kmwwee/
		dx cat project-ByfFPz00jy1fk6PjpZ95F27J:file-BxVGJfj022q45ff2b0j8V73B | tar xf - # ~/stratification-bed-files-f35a0f7.tar -> ~/bed_files/
	elif [[  $genome_reference == "GRCh38" ]]; then
		echo "Using build GRCh38 as genome reference."
		#Extract GRCh38 required resources from assets folder into /home/dnanexus/
		dx cat project-ByfFPz00jy1fk6PjpZ95F27J:file-G33q1Y00xkZ9V4z4Kq2q3kgv | tar xf - #  ~/GCA_000001405.15_GRCh38_no_alt_analysis_set_maskedGRC_exclusions.fasta
		dx cat project-ByfFPz00jy1fk6PjpZ95F27J:file-G2Gb5P80xkZ7Vqf7FJBYykXP | tar zxf - # ~/GCA_000001405.15_GRCh38_no_alt_analysis_set_maskedGRC_exclusions.sdf.tar.gz -> ~/GCA_000001405.15_GRCh38_no_alt_analysis_set_maskedGRC_exclusions.sdf
		dx cat project-ByfFPz00jy1fk6PjpZ95F27J:file-G2GjYXQ0xkZ3jxBj43yXJg43 | tar zxf - # ~/build38_Bed_Stratification.tar.gz -> ~/bed_files/
	else
		echo >&2 "WARNING: No valid genome reference specified."
	fi

	#The files-HG001.tsv for GCRh37, or v2.0-GRCh38-stratifications.tsv for GCRh38, file is a master file containing relative filepaths to all of the bed files used by hap.py for results stratifcation.
	#The stratification tsv must in the parent directory of the bed_files/ directory for relative filepaths to be correct, so copy from /home/dnanexus/bed_files/ > /home/dnanexus/ 
	cp ./bed_files/*.tsv ./

	#The app accepts both uncompressed (.vcf) and gzipped (.vcf.gz) VCF files as input
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

	#Zip VCFs
	bgzip $truth_vcf_path
	bgzip $query_vcf_path
	#Following gzipping, append .gz to vcf filepath variables
	truth_vcf_path=${truth_vcf_path}.gz
	query_vcf_path=${query_vcf_path}.gz
	#Index VCFs
	tabix -p vcf ${truth_vcf_path}
	tabix -p vcf ${query_vcf_path}

	#

	if [[  $genome_reference == "GRCh37" ]]; then
		echo "Using build GRCh37 as genome reference."
		genome_ref_fasta="/data/hs37d5.fa"
		genome_version4log="hs37d5"
	elif [[  $genome_reference == "GRCh38" ]]; then
		echo "Using build GRCh38 as genome reference."
		genome_ref_fasta="/data/GCA_000001405.15_GRCh38_no_alt_analysis_set_maskedGRC_exclusions.fasta"
		genome_version4log="GCA_000001405.15_GRCh38_no_alt_analysis_set_maskedGRC_exclusions"
	else
		echo >&2 "WARNING: No valid genome reference specified."
	fi

	#Run hap.py in docker container
	#The optional arguments used are the same as those used when running the precisionFDA GA4GH Benchmarking in vcfeval-partial-credit mode and other options left as default
	#Mount /home/dnanexus/ to /data/
	#For input files that are stored in /home/dnanexus/in/... replace '/home/dnanexus' with '/data' in filepath using: ${orig_filepath/home\/dnanexus/data} 
	#If sample is flagged as NA12878, use HG001 stratification bed files (indexed in files-HG001.tsv) to provide additional stratification of results
	
	#get docker image and extract
	vcfeval_happy_docker_file_id=project-ByfFPz00jy1fk6PjpZ95F27J:file-G9ZXyyj0jy1VppkQ93ZZFqYG
	dx download ${vcfeval_happy_docker_file_id}
	vcfeval_happy_Docker_image_file=$(dx describe ${vcfeval_happy_docker_file_id} --name)
	vcfeval_happy_Docker_image_name=$(tar xfO "${vcfeval_happy_Docker_image_file}" manifest.json | sed -E 's/.*"RepoTags":\["?([^"]*)"?.*/\1/')

	docker load < /home/dnanexus/"${vcfeval_happy_Docker_image_file}"
	echo "Using docker image ${vcfeval_happy_Docker_image_name}"
	
	if $na12878; then
		docker run -v /home/dnanexus/:/data --rm ${vcfeval_happy_Docker_image_name} /opt/hap.py/bin/hap.py \
			-r ${genome_ref_fasta/home\/dnanexus/data} --stratification data/*.tsv \
			--gender female --decompose --leftshift --adjust-conf-regions \
			--engine vcfeval -f ${high_conf_bed_path/home\/dnanexus/data} -T ${panel_bed_path/home\/dnanexus/data} \
			--ci-alpha 0.05 -o data/"$prefix" ${truth_vcf_path/home\/dnanexus/data} ${query_vcf_path/home\/dnanexus/data}
	#Else if sample is not flagged as NA12878, run same command as above but without the stratification option
	else
		docker run -v /home/dnanexus/:/data --rm ${vcfeval_happy_Docker_image_name} /opt/hap.py/bin/hap.py \
			-r ${genome_ref_fasta/home\/dnanexus/data} \
			--gender female --decompose --leftshift --adjust-conf-regions \
			--engine vcfeval -f ${high_conf_bed_path/home\/dnanexus/data} -T ${panel_bed_path/home\/dnanexus/data} \
			--ci-alpha 0.05 -o data/"$prefix" ${truth_vcf_path/home\/dnanexus/data} ${query_vcf_path/home\/dnanexus/data}
	fi


	# Generate summary_report HTML using ga4gh reporting tool (https://github.com/ga4gh/benchmarking-tools/tree/master/reporting/basic)
	# Input is in the format {method-name}_{comparison-name}:{path-to-hap.py-roc.all.csv.gz-output}
	# Here method name uses the VCF name (replacing underscores with hyphens because underscore is used to separate the 'method' and 'comparison method' fields)
	# and the comparison method is vcfeval-hap.py 
	docker run -v /home/dnanexus/:/data mokaguys/ga4gh_rep.py:v1.0 -o /data/${prefix}.summary_report.html ${prefix//_/-}_vcfeval-hap.py:/data/${prefix}.roc.all.csv.gz

	#Create csv file containing version numbers of resources and apps used.
	echo "#Resource,Version" > "$prefix".version-log.csv
	echo "GIAB(NA12878),v3.3.2" >> "$prefix".version-log.csv
	echo "Reference,"$genome_version4log >> "$prefix".version-log.csv
	echo "hap.py,v0.3.9(Docker)" >> "$prefix".version-log.csv
	echo "tabix,v1.10.2-3" >> "$prefix".version-log.csv

	#Make directories to hold outputs
	mkdir /home/dnanexus/out
	mkdir /home/dnanexus/out/summary_csv
	mkdir /home/dnanexus/out/summary_html
	mkdir /home/dnanexus/out/detailed_results
	#Move outputs to correct directories for upload back to project
	cp "$prefix".summary.csv /home/dnanexus/out/summary_csv/
	cp "$prefix".summary_report.html /home/dnanexus/out/summary_html/
	zip -r /home/dnanexus/out/detailed_results/"$prefix".zip "$prefix".*

	#Upload outputs (from /home/dnanexus/out) to DNAnexus
	dx-upload-all-outputs --parallel
fi