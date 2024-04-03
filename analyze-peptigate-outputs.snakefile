import pandas as pd

metadata = pd.read_csv("inputs/tick_sg_transcriptomes_tsa.csv")
# set the accession as the index to allow us to use loc in params statements below
metadata = metadata.set_index("tsa_accession", drop=False)
TSA_ACCESSIONS = metadata["tsa_accession"].unique().tolist()
ACCESSIONS = TSA_ACCESSIONS, ""

# outputs/tsa_tick_sg_transcriptomes/GANP01/predictions
# peptide_annotations.tsv peptide_predictions.tsv peptides.faa            peptides.ffn            peptides_faa.tsv        peptides_ffn.tsv

rule combine_peptigate_protein_peptide_sequences:
    input: expand("outputs/tsa_tick_sg_transcriptomes/{accessions}/predictions/peptides.faa"),
    output: faa="outputs/analysis/peptigate_outputs_combined/all_peptides.faa"
    shell:
        """
        cat {input} > {output}
        """

rule combine_peptigate_parent_protein_sequences:
    input:
        expand("outputs/tsa_tick_sg_transcriptomes/{accessions}/cleavage/nlpprecursor/nlpprecursor_peptide_parents.faa", accession = ACCESSIONS),
        expand("outputs/tsa_tick_sg_transcriptomes/{accessions}/cleavage/deeppeptide/deeppeptide_peptide_parents.faa", accession = ACCESSIONS)
    output: faa="outputs/analysis/peptigate_outputs_combined/all_cleavage_parent_peptides.faa"
    shell:
        """
        cat {input} > {output}
        """

#########################################################
## Cluster peptide sequences
#########################################################
"""
Clustering groups peptides with similar sequences.
This allows us to approximate whether the same (or similar) peptides were predicted in many
transcriptomes. Especially when the transcriptomes are from different tick species, this may give
us more confidence that the peptide sequence is real. It also provides preliminary evolutionary
support of the peptide, but we don't distinguish between the evolutionary regimes that could have
given rise to the sequence like:
* the peptide evolved from a common ancestor and was retained in different species.
* the peptide evolved independently multiple times (convergent evolution).
* the peptide was horizontally transferred to or between multiple tick species.

We selected 80% as a percent identity cutoff for clustering.
This is the percent identity cutoff frequently used prior to training a machine learning classifier
to make sure there is no shared sequences/signal between training and testing data sets.
We assume that 80% similarlity is a nice balance between clustering peptides that have shared
sequence and function and retaining diversity/heterogeneity of peptides in the data set.
"""

rule cluster_peptigate_protein_peptide_sequences:
    input: faa=rules.combine_peptigate_protein_peptide_sequences.output.faa
    output:
        faa="outputs/clustering/all_peptides_0.8_rep_seq.fasta",
        tsv="outputs/clustering/all_peptides_0.8_cluster.tsv"
    params: out_prefix = "outputs/clustering/"
    conda: "envs/mmseqs2.yml"
    shell:
        """
        mkdir -p tmp
        mmseqs easy-cluster {input} mmseqs/all_peptide_predictions_0.8 tmp --min-seq-id 0.8 
        """



#########################################################
## Predict anti-inflammatory bioactivity 
#########################################################

rule unzip_autopeptideml_antiinflammatory_model:
    """
    The anti-inflammatory model is part of this github repository.
    Issue [#2](https://github.com/Arcadia-Science/2024-tick-sg-peptides-tsa/issues/2) documents how
    we built it.
    """
    input: "inputs/autopeptideml_antiinflammatory/apml_antiinflammatory_length15.zip"
    output: json="inputs/autopeptideml_antiinflammatory/apml_antiinflammatory_length15/config.json"
    params: outdir = "inputs/autopeptideml_antiinflammatory/apml_antiinflammatory_length15/"
    shell:
        """
        mkdir -p {params.outdir}
        unzip {input} -d {params.outdir}
        """

rule download_autopeptideml_run_script_from_peptigate:
   """
   Note this won't work until the peptigate repo is public.
   I did this step by hand but I'm adding the rule as a placeholder.
   I think this is preferable over checking in the script here as well so that it doesn't become
   duplicated and need to be updated as the peptigate repo changes.
   """
    output: "scripts/run_autopeptideml.py"
    shell:
        """
        curl -JLo {output}
        """

rule predict_antiinflammatory_bioactivity_with_autopeptideml:
    input:
        script=rule.download_autopeptideml_run_script_from_peptigate.output,
        model=rule.unzip_autopeptideml_antiinflammatory_model.output.json,
        faa=rules.combine_peptigate_protein_peptide_sequences.output.faa
    output:
        tsv="outputs/analysis/predict_antiinflammatory/autopeptideml_antiinflammatory_predictions.tsv"
    params: model_dir="inputs/autopeptideml_antiinflammatory/apml_antiinflammatory_length15/ensemble"
    conda: "envs/autopeptideml.yml"
    shell:
        """
        python scripts/run_autopeptideml.py \
            --input_fasta  {input.faa} \
            --model_folder {params.model_dir} \
            --model_name antiinflammatory \
            --output_tsv {output.tsv}
        """


#########################################################
## Compare against human peptides 
#########################################################
"""
With this analysis, we hope to identify tick peptides that potentially mimic human peptides.
These peptides may have evolved to interact with humans and to control specific aspects of human
phsyiology (coagulation, itch, inflammation, etc.). 

Note that peptipedia does contain peptides from the human peptide atlas so some hits will be
redundant with those reported by peptigate. It is difficult to extract taxonomy information from
peptipedia and BLASTp is relatively inexpensive to run, so we implemented this specific comparison
step.

The human peptide atlas contains tryptic peptides (degradation products from enzymatic digestion.).
While we are not interested in these, we are relying on our tools to limit hits to these peptides
because we anticipate that peptigate will only predict bioactive peptides.
"""

rule download_human_peptide_atlas_peptide_sequences:
    output: "inputs/databases/humanpeptideatlas/APD_Hs_all.fasta"
    shell:
        """
        curl -JLo {output} https://peptideatlas.org/builds/human/202401/APD_Hs_all.fasta
        """

rule make_diamond_blastdb_for_human_peptide_atlas:
    input: rules.download_human_peptide_atlas_peptide_sequences.output
    output: dmnd="inputs/databases/humanpeptideatlas/APD_Hs_all.dmnd"
    conda: "envs/diamond.yml"
    params: dbprefix = "inputs/databases/humanpeptideatlas/APD_Hs_all"
    shell:
        """
        diamond makedb --in {input.db} -d {params.dbprefix}
        """

rule blastp_peptide_predictions_against_human_peptide_atlas:
    input:
        db=rules.make_diamond_blastdb_for_human_peptide_atlas.output.dmnd,
        faa=rules.combine_peptigate_protein_peptide_sequences.output.faa
    output:
        tsv="outputs/analysis/compare_human/humanpeptideatlas_blastp_matches.tsv",
    params:
        dbprefix="inputs/databases/humanpeptideatlas/APD_Hs_all"
    conda:
        "envs/diamond.yml"
    shell:
        """
        diamond blastp -d {params.dbprefix} -q {input.peptide_faa} -o {output.tsv} --header simple \
         --outfmt 6 qseqid sseqid full_sseq pident length qlen slen mismatch gapopen qstart qend sstart send evalue bitscore
        """

#########################################################
## Compare agaist known anti-pruritic peptides
#########################################################
"""
Unlike with anti-inflammatory peptides, there are relatively few examples of anti-pruritic peptides
in the literature. This means that are not enough examples of anti-pruritic peptides to train a
machine learning model that can detect this bioactivity. This set of rules uses BLASTp to compare
peptigate predicted peptides against anti-pruritic peptides.
"""

#rule download_antipruritic_peptide_sequences:

#rule combine_antipruritic_peptide_sequences:

#rule make_diamond_blastdb_for_antipruritic_peptide_sequences:

#rule blastp_peptide_predictions_against_antipruritic_peptides:


#########################################################
## Annotate parent ORFs
#########################################################
"""
ChatGPT stated that parent sequences of cleavage peptides might give clues as to the function of
their cleavage products.

This module takes advantage of the longer sequence length of parent peptide sequences and performs
functional annotation to provide additional metadata about potential peptide function.
"""

rule download_kofamscan_ko_list:
    """
    This rule downloads the kofamscan KEGG list file.
    """
    output: kolist="inputs/databases/kofamscandb/ko_list"
    shell:'''
    curl -JLo {output}.gz ftp://ftp.genome.jp/pub/db/kofam/ko_list.gz && \
        gunzip -c {output}.gz > {output}
    '''

rule download_kofamscan_profiles:
    """
    This rule downloads the kofamscan KEGG hmm profiles.
    """
    output: profiles="inputs/databases/kofamscandb/profiles/eukaryote.hal"
    params: outdir = "inputs/databases/kofamscandb/"
    shell:'''
    curl -JLo {params.outdir}/profiles.tar.gz ftp://ftp.genome.jp/pub/db/kofam/profiles.tar.gz && \
        tar xf {params.outdir}/profiles.tar.gz -C {params.outdir}
    '''

rule annotate_cleavage_peptide_parent_proteins_with_kofamscan:
    """
    This rule uses the kofamscan to perform KEGG ortholog annotation on parent proteins of cleavage
    peptides. 
    """
    input:
        faa=rules.combine_peptigate_parent_protein_sequences.output.faa
        kolist=rules.download_kofamscan_ko_list.output.kolist
        profiles=rules.download_kofamscan_profiles.profiles
    output: tsv="outputs/analysis/annotate_cleavage_parent_proteins/kofamscan.tsv"
    conda: "envs/kofamscan.yml"
    params: profilesdir = "outputs/databases/kofamscandb/profiles"
    threads: 8
    shell:'''
    exec_annotation --format detail-tsv \
        --ko-list {input.kolist} \
        --profile {params.profilesdir} \
        --cpu {threads} -o {output} {input.faa}
    '''

rule download_eggnog_db:
    """
    This rule downloads the eggnog annotation database.
    The script download_eggnog_data.py is exported by the eggnog mapper tool.
    """
    output: db="inputs/databases/eggnog_db/eggnog.db"
    params: dbdir = "inputs/databases/eggnog_db"
    conda: "envs/eggnog.yml"
    shell:'''
    download_eggnog_data.py -H -d 2 -y --data_dir {params.dbdir}
    '''

rule annotate_cleavage_peptide_parent_proteins_with_eggnog:
    '''
    This rule uses the EggNOG database to functionally annotate the parent proteins of cleavage
    peptides.  It runs the EggNOG-Mapper tool, generating a file with the annotations (NOG, KEGG,
    PFAM, CAZys, EC numbers) for each gene. The script emapper.py is exported by the eggnog mapper
    tool.
    '''
    input:
        db=rules.download_eggnog_db.output.db,
        faa=rules.combine_peptigate_parent_protein_sequences.output.faa
    output: tsv="outputs/analysis/annotate_cleavage_parent_proteins/eggnog.emapper.annotations"
    conda: "envs/eggnog.yml"
    params:
        outdir="outputs/analysis/annotate_cleavage_parent_proteins/",
        dbdir = "inputs/databases/eggnog_db/",
    threads: 8
    shell:'''
    mkdir -p tmp
    emapper.py --cpu {threads} -i {input.fa} --output eggnog \
       --output_dir {params.outdir} -m diamond --tax_scope none \
       --seed_ortholog_score 60 --override --temp_dir tmp/ \
       --data_dir {params.dbdir}
    '''


#########################################################
## Collect outputs 
#########################################################

rule all:
    default_target: True
    input:
        rule.blastp_peptide_predictions_against_human_peptide_atlas.output.tsv,
        rule.predict_antiinflammatory_bioactivity_with_autopeptideml.output.tsv,
        rule.cluster_peptigate_protein_peptide_sequences.output.tsv,
        rule.annotate_cleavage_peptide_parent_proteins_with_eggnog.output.tsv,
        rule.annotate_cleavage_peptide_parent_proteins_with_kofamscan.output.tsv

