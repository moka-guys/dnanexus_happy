# vcfeval_hap.py v1.3

## hap.py version
v0.3.9 (Docker: https://hub.docker.com/r/pkrusche/hap.py/)


## What does this app do?
Compares a query VCF to a truth VCF to calculate performance metrics including sensitivity and precision using hap.py and vcfeval. It is equivalent to running the precisionFDA GA4GH benchmarking app in 'vcfeval-partialcredit' mode with other options left as default. More information available at the following links:
* https://precision.fda.gov/apps/app-F5YXbp80PBYFP059656gYxXQ
* https://github.com/ga4gh/benchmarking-tools/tree/master/doc/ref-impl

## What are typical use cases for this app?
Validating an NGS workflow using the NA12878 (NIST Genome in a Bottle) benchmarking sample.

## What data are required for this app to run?

Input files:
1. A query VCF (.vcf | .vcf.gz) - *output from the workflow being validated*
2. A truth VCF (.vcf | .vcf.gz)
3. A panel BED file (.bed) - *region covered in query vcf*
4. A high confidence region BED file (.bed) - *high confidence region for truth set*

Parameters:
1. Output files prefix (required)
2. Output folder (optional)
3. Indication if additional stratification for NA12878 samples should be performed (default = False)
    * If truth set is NA12878, additional stratification of results can be performed and output in extended.csv file
    * *HOWEVER* the instance type will need to be upgraded to have at least 7GB of RAM, and the app will take significantly longer to run

Note:  
* The BED file names must not contain spaces or characters such as + and -


## What does this app output?

This app outputs:
1. Summary csv file containing separate performance metrics for SNPs and Indels
2. Summary report HTML (generated using ga4gh rep.py https://github.com/ga4gh/benchmarking-tools/tree/master/reporting/basic)
3. Detailed results folder containing:
    * Extended csv file - *Including results stratification and confidence intervals*
    * VCF file - *annotated vcf showing TP, FP and FN variants*
    * runinfo JSON - *detailed information about hap.py run*
    * version log - *version numbers of software used in app*
    * metrics JSON - *JSON file containing all computed metrics and tables*


## How does this app work?

* 'chr' is stripped from the chromosome field of the VCF and BED files (if hg19 format used)
* Indexed and zipped VCF files passed to hap.py:
   * Uses vcfeval comparison engine
   * If the sample is NA12878, additional stratification is performed using bed files found here: https://github.com/ga4gh/benchmarking-tools/tree/master/resources/stratification-bed-files
   * Summary HTML is generated

## What are the limitations of this app
* Only works with inputs mapped to GRCh37

## This app was made by Viapath Genome Informatics
