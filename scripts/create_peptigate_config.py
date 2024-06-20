import argparse


def write_peptigate_config(tsa_accession, fasta, fasta_cds_aa, fasta_cds_na, output_file):
    config_template = """\
input_dir: "inputs/"
output_dir: "outputs/tsa_tick_sg_transcriptomes/{tsa_accession}/"
contigs: {fasta}
orfs_amino_acids: {fasta_cds_aa}
orfs_nucleotides: {fasta_cds_na}
plmutils_model_dir: "inputs/models/plmutils/"
"""
    with open(output_file, "w") as fp:
        fp.write(
            config_template.format(
                fasta=fasta,
                tsa_accession=tsa_accession,
                fasta_cds_aa=fasta_cds_aa,
                fasta_cds_na=fasta_cds_na,
            )
        )


def main():
    parser = argparse.ArgumentParser(description="Create PeptiGate configuration file.")
    parser.add_argument("--tsa_accession", required=True, help="TSA accession number")
    parser.add_argument("--fasta", required=True, help="Transcriptome FASTSA file path")
    parser.add_argument("--fasta_cds_aa", required=True, help="FASTA CDS amino acids file path")
    parser.add_argument("--fasta_cds_na", required=True, help="FASTA CDS nucleotides file path")
    parser.add_argument("--output", required=True, help="Output configuration file path")
    args = parser.parse_args()

    write_peptigate_config(
        tsa_accession=args.tsa_accession,
        fasta=args.fasta,
        fasta_cds_aa=args.fasta_cds_aa,
        fasta_cds_na=args.fasta_cds_na,
        output_file=args.output,
    )


if __name__ == "__main__":
    main()
