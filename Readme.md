# vcfeval_hap.py v1.0

## What does this app do?
Compares a query VCF to a truth VCF to calculate performance metrics including sensitivity and precision. It is based on the precisionFDA benchmarking tool and uses the vcfeval comparison engine in combination with hap.py. More information available at the following links:
* https://precision.fda.gov/challenges/truth/results
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
2. Detailed results folder containing:
    * Extended csv file - *contains performance metrics at multiple stratification levels*
    * ROC analysis files
    * VCF file - *contains TP, FP and FN variants*


## How does this app work?

* 'chr' is stripped from the chromosome field of the VCF and BED files (if hg19 format used)
* bedtools is used to create an intersect BED from high conf and panel BED files
* Indexed and zipped VCF files passed to hap.py:
   * Uses vcfeval comparison engine
   * If the sample is NA12878, additional stratification is performed using bed files found here: https://github.com/ga4gh/benchmarking-tools/tree/master/resources/stratification-bed-files

## What are the limitations of this app
* Only works with inputs mapped to GRCh37

## This app was made by Viapath Genome Informatics
