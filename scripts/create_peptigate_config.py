import argparse


def write_peptigate_config(tsa_accession, fasta_cds_aa, fasta_cds_na, empty, fasta, output_file):
    config_template = """\
input_dir: "inputs/"
output_dir: "outputs/tsa_tick_sg_transcriptomes/{tsa_accession}/"
orfs_amino_acids: {fasta_cds_aa}
orfs_nucleotides: {fasta_cds_na}
contigs_shorter_than_r2t_minimum_length: {empty}
contigs_longer_than_r2t_minimum_length: {fasta}
plmutils_model_dir: "inputs/models/plmutils/"
"""
    with open(output_file, "w") as fp:
        fp.write(
            config_template.format(
                tsa_accession=tsa_accession,
                fasta_cds_aa=fasta_cds_aa,
                fasta_cds_na=fasta_cds_na,
                empty=empty,
                fasta=fasta,
            )
        )


def main():
    parser = argparse.ArgumentParser(description="Create PeptiGate configuration file.")
    parser.add_argument("--tsa_accession", required=True, help="TSA accession number")
    parser.add_argument("--fasta_cds_aa", required=True, help="Fasta CDS amino acids file path")
    parser.add_argument("--fasta_cds_na", required=True, help="Fasta CDS nucleotides file path")
    parser.add_argument("--empty", required=True, help="Empty fasta file path")
    parser.add_argument("--fasta", required=True, help="Fasta file path")
    parser.add_argument("--output", required=True, help="Output configuration file path")
    args = parser.parse_args()

    write_peptigate_config(
        tsa_accession=args.tsa_accession,
        fasta_cds_aa=args.fasta_cds_aa,
        fasta_cds_na=args.fasta_cds_na,
        empty=args.empty,
        fasta=args.fasta,
        output_file=args.output,
    )


if __name__ == "__main__":
    main()
