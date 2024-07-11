# 2024-tick-sg-peptides-tsa: Predicting peptide sequences from tick salivary gland transcriptomes in the Transcriptome Shotgun Assembly database 

[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/projects/miniconda/en/latest/)
[![Snakemake](https://img.shields.io/badge/snakemake--green)](https://snakemake.readthedocs.io/en/stable/)

## Purpose

This repository documents peptide discovery in tick salivary gland transcriptomes on the [TSA](https://www.ncbi.nlm.nih.gov/genbank/tsa/).

## Installation and Setup

This repository uses Snakemake to run the pipeline and conda to manage software environments and installations. You can find operating system-specific instructions for installing miniconda [here](https://docs.conda.io/projects/miniconda/en/latest/). After installing conda and [mamba](https://mamba.readthedocs.io/en/latest/), run the following command to create the pipeline run environment.

```{bash}
mamba env create -n ticktides --file envs/dev.yml
conda activate ticktides
```

Snakemake manages rule-specific environments via the `conda` directive and using environment files in the [envs/](./envs/) directory. Snakemake itself is installed in the main development conda environment as specified in the [dev.yml](./envs/dev.yml) file.

The pipeline progresses in three stages.
In the first, tick transcriptomes are prepped for the peptigate pipeline using the [`prep-txomes-for-peptigate.snakefile`](./prep-txomes-for-peptigate.snakefile).
It uses the metadata file [tick_sg_transcriptomes_tsa.csv](./inputs/tick_sg_transcriptomes_tsa.csv) to download tick transcriptomes from the TSA and predict protein sequences with TransDecoder.
It also produces config files for peptigate.
This snakefile can be run with:

```{bash}
snakemake -s prep-txomes-for-peptigate.snakefile --software-deployment-method conda -j 8
```

Then, supply this processed data and config files to run peptigate.
The peptigate pipeline predicts peptides (sORF and cleavage) from transcriptome assemblies.
We run this as a separate step because peptigate is its own Snakemake workflow in a GitHub repository and is not currently installable.
We ran peptigate from the commit [148823239aad41a8f03da37f5499b00c8a79de40](https://github.com/Arcadia-Science/peptigate/commit/148823239aad41a8f03da37f5499b00c8a79de40).
We cloned the repository, copied our config and input data files to the repo folder, and ran peptigate with this for loop:

```{bash}
for infile in input_configs/tsa_tick_sg_transcriptomes/*yml
do
snakemake --software-deployment-method conda -j 1 -k --configfile $infile
done  
```

We then transferred the results back to this repo into the `outputs/tsa_tick_sg_transcriptomes` folder and analyzed them with the snakefile [`analyze-peptigate-outputs.snakefile`](./analyze-peptigate-outputs.snakefile).

```{bash}
snakemake -s analyze-peptigate-outputs.snakefile --software-deployment-method conda -j 8 -k
```

Finally, we analyzed the results from this last snakefile using the notebooks in the [notebooks](./notebooks) directory.
To run these notebooks, we use the `tidyjupyter` environment:

```{bash}
mamba env create -n tidyjupyter --file envs/tidyjupyter.yml
conda activate tidyjupyter
```

## Notes about the pipeline

### [`prep-txomes-for-peptigate.snakefile`](./prep-txomes-for-peptigate.snakefile)

The TSA is notoriously unreliable for downloading files.
While in theory one should be able to download transcriptome assemblies and predicted proteins directly from the TSA using NCBI's [Entrez-Direct](https://www.ncbi.nlm.nih.gov/books/NBK179288/) tool, in practice this approach is spotty due to outages.
When using this approach, we received error message like the following for a subset of transcriptomes:

```
$ esearch -db nuccore -query GKHV01 |             efetch -format fasta > GKHV01_fasta.fa
 WARNING:  FAILURE ( Wed Mar 27 18:04:01 UTC 2024 )
nquire -url https://eutils.ncbi.nlm.nih.gov/entrez/eutils/ efetch.fcgi -query_key 1 -WebEnv MCID_66045f91e16b2b7f5e329221 -retstart 0 -retmax 1 -db nuccore -rettype fasta -retmode text -tool edirect -edirect 21.6 -edirect_os Linux -email ubuntu@ip-172-31-6-147.us-west-1.compute.internal
EMPTY RESULT
SECOND ATTEMPT
 WARNING:  FAILURE ( Wed Mar 27 18:04:04 UTC 2024 )
nquire -url https://eutils.ncbi.nlm.nih.gov/entrez/eutils/ efetch.fcgi -query_key 1 -WebEnv MCID_66045f91e16b2b7f5e329221 -retstart 0 -retmax 1 -db nuccore -rettype fasta -retmode text -tool edirect -edirect 21.6 -edirect_os Linux -email ubuntu@ip-172-31-6-147.us-west-1.compute.internal
EMPTY RESULT
LAST ATTEMPT
 ERROR:  FAILURE ( Wed Mar 27 18:04:06 UTC 2024 )
nquire -url https://eutils.ncbi.nlm.nih.gov/entrez/eutils/ efetch.fcgi -query_key 1 -WebEnv MCID_66045f91e16b2b7f5e329221 -retstart 0 -retmax 1 -db nuccore -rettype fasta -retmode text -tool edirect -edirect 21.6 -edirect_os Linux -email ubuntu@ip-172-31-6-147.us-west-1.compute.internal
EMPTY RESULT
QUERY FAILURE
``` 

We received this error:
* With and without using an NCBI API
* With the entrez-direct tool installed via NCBI's installation method or via conda
* On a local (MacOS) computer and on an AWS EC2 instance.

As such, we provide a backup url from which to download the transcriptome assemblies.
This two-step download approach is baked into the Snakefile.
Further, while one can programmatically download protein predictions in amino acid or nucleotide format if they are available using entrez-direct, the TSA only provides links for the contigs in nucleotide format or the proteins in amino acid format.
Given this, and how spotty entrez-direct coverage of the TSA is, we chose to predict proteins using TransDecoder for all transcriptomes, whether they have annotations available or not.
These decisions are documented in docstrings in the Snakefile and executed with the code itself.
 
## Data

TODO: Add details about the description of input / output data and links to Zenodo depositions, if applicable.

## Overview

### Description of the folder structure

### Description of how the tool works

**Tips for Developers**

You should consider having a quickstart guide for users who want to run the pipeline, and/or a demo dataset that they can use to test the pipeline.  
When you're ready to share, please delete this section.

### Compute Specifications

* [`prep-txomes-for-peptigate.snakefile`](./prep-txomes-for-peptigate.snakefile): Ran on a MacBookPro 2021 with 64 Gb of RAM and running MacOS Ventura 13.4. We executed all commands in a terminal running Rosetta.
* peptigate pipeline: Ran on an AWS EC2 instance type `g4dn.2xlarge` running AMI Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 20.04) 20240122 (AMI ID ami-07eb000b3340966b0). Note the pipeline runs many tools that use GPUs. 
* [`analyze-peptigate-outputs.snakefile`](./analyze-peptigate-outputs.snakefile): Ran on an AWS EC2 instance type `g4dn.2xlarge` running AMI Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 20.04) 20240122 (AMI ID ami-07eb000b3340966b0). Note the tool AutoPeptideML runs on a GPU.

## Contributing

See how we recognize [feedback and contributions to our code](https://github.com/Arcadia-Science/arcadia-software-handbook/blob/main/guides-and-standards/guide-credit-for-contributions.md).
