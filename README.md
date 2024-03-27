# TODO: Replace with the name of the repo

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

TBD

Lastly, we analyze the results of the peptigate pipeline.

TBD

## Notes about the pipeline

### [`prep-txomes-for-peptigate.snakefile`](./prep-txomes-for-peptigate.snakefile)

The TSA is notoriously unreliable for downloading files.
While in theory one should be able to download transcriptome assemblies and predicted proteins directly from the TSA using NCBI's [Entrez-Direct](https://www.ncbi.nlm.nih.gov/books/NBK179288/) tool, in practice this approaches is spotty and suffers from outages.
When using this approach, we received error message like the following:

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

We received this error with and without using an API and with the entrez-direct tool installed via NCBI's installation method or via conda.
As such, we provide a backup url from which to download the transcriptome assemblies.
Further, while one can programmatically download protein predictions in amino acid or nucleotide format if they are available  using entrez-direct, the TSA only provides links for the contigs in nucleotide format or the proteins in amino acid format.
Given this, and how spotty entrez-direct coverage of the TSA is, we chose to predict proteins using TransDecoder for all transcriptomes, whether they have annotations available or not.
This is documented in line in the snakefile.
 
**Tips for Developers**

You can use the following command to export your current conda environment to a `yml` file.  
This command will only export the packages that you have installed directly, not the ones that were installed as dependencies. When you're ready to share, please delete this section.

```{bash}
conda env export --from-history --no-builds > envs/dev.yml
```

## Data

TODO: Add details about the description of input / output data and links to Zenodo depositions, if applicable.

## Overview

### Description of the folder structure

### Description of how the tool works

**Tips for Developers**

You should consider having a quickstart guide for users who want to run the pipeline, and/or a demo dataset that they can use to test the pipeline.  
When you're ready to share, please delete this section.

### Compute Specifications

TODO: Describe what compute resources were used to run the analysis. For example, you could list the operating system, number of cores, RAM, and storage space.

## Contributing

See how we recognize [feedback and contributions to our code](https://github.com/Arcadia-Science/arcadia-software-handbook/blob/main/guides-and-standards/guide-credit-for-contributions.md).

---
## For Developers

This section contains information for developers who are working off of this template. Please delete this section when you're ready to share your repository.

### GitHub templates
This template uses GitHub templates to provide checklists when making new pull requests as well as templates for issues, which could be used to request new features or report bugs. These templates are stored in the [.github/](./.github/) directory.

### VSCode
This template includes recommendations to VSCode users for extensions, particularly the `ruff` linter. These recommendations are stored in `.vscode/extensions.json`. When you open the repository in VSCode, you should see a prompt to install the recommended extensions. 

### `.gitignore`
This template uses a `.gitignore` file to prevent certain files from being committed to the repository.

### `pyproject.toml`
`pyproject.toml` is a configuration file to specify your project's metadata and to set the behavior of other tools such as linters, type checkers etc. You can learn more [here](https://packaging.python.org/en/latest/guides/writing-pyproject-toml/)

### Linting
This template automates linting and formatting using GitHub Actions and the `ruff` and `snakefmt` linters. When you push changes to your repository, GitHub will automatically run the linter and report any errors, blocking merges until they are resolved.

### Testing
This template uses GitHub Actions to automate a test dry run of the pipeline. When you push changes to your repository, GitHub will automatically run the tests and report any errors, blocking merges until they are resolved.
