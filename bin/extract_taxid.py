#!/usr/bin/env python3

import argparse
import pandas as pd

def main(file_path):
    emu_result = pd.read_csv(file_path, sep="\t")
    emu_result.rename(columns={"Unnamed: 0": "read_id"}, inplace=True)
    emu_transposed = emu_result.melt(id_vars="read_id")
    emu_transposed.dropna(subset=["value"], inplace=True)
    emu_transposed.sort_values(by=["read_id", "value"], inplace=True)
    emu_transposed.drop_duplicates(subset=["read_id"], keep='last', inplace=True)
    emu_transposed["variable"].to_csv("taxids.tmp", sep="\t", header=False, index=False)

def parse_args():
    parser = argparse.ArgumentParser(description='Process a TSV file.')
    parser.add_argument('file', type=str, help='path to the TSV file')
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_args()
    main(args.file)