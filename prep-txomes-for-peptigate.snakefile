import pandas as pd

metadata = pd.read_csv("inputs/tick_sg_transcriptomes_tsa.csv")
# set the accession as the index to allow us to use loc in params statements below
metadata = metadata.set_index("tsa_accession", drop=False)
TSA_ACCESSIONS = metadata["tsa_accession"].unique().tolist()
# Note that this file variable is important as it is used to create the config file.
FILETYPES = ["fasta_cds_aa", "fasta_cds_na", "fasta"]


rule all:
    input:
        expand(
            "input_configs/tsa_tick_sg_transcriptomes/{tsa_accession}_config.yml",
            tsa_accession=TSA_ACCESSIONS,
        ),


rule download_transcriptomes:
    """
    This rule downloads the assembled transcriptome by the Transcriptome Shotgun Assembly accession.
    It first tries to download via Entrez-Direct, NCBI's recommended tool for downloads.
    The tool only requires an accession to download files which makes it easy to use.
    However, it suffers from frequent, unpredictable, and spotty outages that make it hard to use.
    As such, we've encoded a backup URL from which to directly download the transcriptome from the
    TSA. This method is only used after the first method produces an empty file. 
    
    To enable this backup method of download, we searched the TSA for each accession and found each
    download link and recorded each in the metadata table. The links follow a formulaic pattern
    except for the "wgs" section (ex. wgs01). We thought it was easier to retrieve the URLs than
    to ping NCBI repeatedly to figure out which wgs section the transcriptome assembly was stored
    in.
    """
    output:
        "input_data/tsa_tick_sg_transcriptomes/{tsa_accession}/{tsa_accession}_fasta.fa",
    params:
        backup_url=lambda wildcards: metadata.loc[wildcards.tsa_accession, "backup_url"],
    conda:
        "envs/entrez-direct.yml"
    shell:
        """
        set +e
        esearch -db nuccore -query {wildcards.tsa_accession} | \
            efetch -format fasta > {output}
        if [ ! -s {output} ]; then
            rm -f {output}
            curl -s {params.backup_url} | gunzip -c > {output}
        fi
        """


rule predict_proteins_with_transdecoder:
    """
    Initially, we had a bash if statement controlling whether or not to download the CDS sequences
    from the TSA directly or to predict the CDS sequences using transdecoder. We removed this and
    predicted all sequences with transdecoder because entrez-direct had so many outages and felt it
    was better to keep protein prediction consistent.
    """
    input:
        fa="input_data/tsa_tick_sg_transcriptomes/{tsa_accession}/{tsa_accession}_fasta.fa",
    output:
        fasta_cds_aa="input_data/tsa_tick_sg_transcriptomes/{tsa_accession}/{tsa_accession}_fasta_cds_aa.fa",
        fasta_cds_na="input_data/tsa_tick_sg_transcriptomes/{tsa_accession}/{tsa_accession}_fasta_cds_na.fa",
    params:
        tmp_outdir="tmp/transdecoder/",
    conda:
        "envs/transdecoder.yml"
    shell:
        """
        TransDecoder.LongOrfs -t {input} --output_dir {params.tmp_outdir}
        TransDecoder.Predict -t {input} --output_dir {params.tmp_outdir} --no_refine_starts
        mv {params.tmp_outdir}/{wildcards.tsa_accession}_fasta.fa.transdecoder.pep {output.fasta_cds_aa}
        mv {params.tmp_outdir}/{wildcards.tsa_accession}_fasta.fa.transdecoder.cds {output.fasta_cds_na}
        """


rule touch_empty_file:
    """
    peptigate takes four input files:
        * coding sequences as amino acid
        * coding sequences as nucleotide
        * contigs
        * short contigs that didn't make it into the final assembly
    The TSA transcriptomes don't have separate short contigs.
    This rule generates an empty file to use as a place holder for that input file.
    """
    output:
        touch("input_data/tsa_tick_sg_transcriptomes/{tsa_accession}/{tsa_accession}_empty.fa"),


rule create_peptigate_config:
    input:
        tsa=expand(
            "input_data/tsa_tick_sg_transcriptomes/{{tsa_accession}}/{{tsa_accession}}_{filetype}.fa",
            filetype=FILETYPES,
        ),
        empty="input_data/tsa_tick_sg_transcriptomes/{tsa_accession}/{tsa_accession}_empty.fa",
    output:
        config="input_configs/tsa_tick_sg_transcriptomes/{tsa_accession}_config.yml",
    run:
        fasta_cds_aa = str(input[0])
        fasta_cds_na = str(input[1])
        fasta = str(input[2])
        config_template = """\
                                        input_dir: "inputs/"
                                        output_dir: "outputs/tsa_tick_sg_transcriptomes/{tsa_accession}/"
                                        orfs_amino_acids: {fasta_cds_aa}
                                        orfs_nucleotides: {fasta_cds_na}
                                        contigs_shorter_than_r2t_minimum_length: {empty}
                                        contigs_longer_than_r2t_minimum_length: {fasta}
                                        plmutils_model_dir: "inputs/models/plmutils/"
                                        """
        with open(output.config, "wt") as fp:
            fp.write(
                config_template.format(
                    tsa_accession=wildcards.tsa_accession,
                    fasta_cds_aa=fasta_cds_aa,
                    fasta_cds_na=fasta_cds_na,
                    empty=str(input.empty),
                    fasta=fasta,
                )
            )
