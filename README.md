# wf-metagenomics
This is the modified version from the original pipeline `epi2me-labs/wf-metagenomics` see [original README](README.original.md) with the software `emu` being added.
### Input

This pipeline requires input structure like below:

```
 ─── input_directory        ─── input_directory
    ├── reads0.fastq            ├── barcode01
    └── reads1.fastq            │   ├── reads0.fastq
                                │   └── reads1.fastq
                                ├── barcode02
                                │   ├── reads0.fastq
                                │   ├── reads1.fastq
                                │   └── reads2.fastq
                                └── barcode03
                                    └── reads0.fastq
```

Each *barcode* can have a single fastq.gz; you can then prepare a sample sheet file to get the sample name reported instead the barcode

```
barcode,alias
barcode01,sample1
barcode02,sample2
barcode03,sample3
```
### Quick command
```bash
nextflow run thanhleviet/wf-metagenomics \
-r custom-db \
--reference "https://quadram-bioinfo-demo.s3.climb.ac.uk/16S/U16S.BLAST_format.thanhlv.fa.gz" \
--fastq /input/data \
--sample_sheet /path/to/sample_sheet.csv \
--custom_db \
--out_dir "output" \
--emu_db "https://quadram-bioinfo-demo.s3.climb.ac.uk/16S/emu-db.tar.gz" \
--threads 32 \
-resume

```
### Usage

```bash
||||||||||   _____ ____ ___ ____  __  __ _____      _       _
||||||||||  | ____|  _ \_ _|___ \|  \/  | ____|    | | __ _| |__  ___
|||||       |  _| | |_) | |  __) | |\/| |  _| _____| |/ _` | '_ \/ __|
|||||       | |___|  __/| | / __/| |  | | |__|_____| | (_| | |_) \__ \
||||||||||  |_____|_|  |___|_____|_|  |_|_____|    |_|\__,_|_.__/|___/
||||||||||  wf-metagenomics v2.3.0
--------------------------------------------------------------------------------
Typical pipeline command:

  nextflow run epi2me-labs/wf-metagenomics \ 
        --fastq test_data/case01/barcode01/reads.fastq.gz

Input Options
  --fastq                [string]  A fastq file or a directory of directories containing fastq input files.
  --classifier           [string]  Kraken2 or Minimap2 workflow to be used for classification of reads. [default: mapping]
  --batch_size           [integer] Maximum number of sequence records to process in a batch.
  --analyse_unclassified [boolean] Analyse unclassified reads from input directory. By default the workflow will not process reads in the unclassified 
                                   directory. 

Real Time Analysis Options
  --watch_path           [boolean] Enable to continuously watch the input directory for new input files. Reads will be analysed as they appear
  --read_limit           [integer] Stop processing data when a particular number of reads have been analysed. By default the workflow will run 
                                   indefinitely. 

Sample Options
  --sample_sheet         [string]  A CSV file used to map barcodes to sample aliases. The sample sheet can be provided when the input data is a directory 
                                   containing sub-directories with FASTQ files. Used only with the minimap2 classifier. 
  --sample               [string]  A single sample name for non-multiplexed data. Permissible if passing a single .fastq(.gz) file or directory of .fastq(.gz) 
                                   files. 

Reference Options
  --database_set         [string]  Sets the reference, databases and taxonomy datasets that will be used for classifying reads. Choices: 
                                   ['ncbi_16s_18s','ncbi_16s_18s_28s_ITS','PlusPF-8']. Workflow will require memory available to be slightly higher than the 
                                   size of the database. PlusPF-8 database requires more than 8Gb. [default: ncbi_16s_18s] 
  --database             [string]  Not required but can be used to specifically override kraken2 database [.tar.gz or Directory].
  --taxonomy             [string]  Not required but can be used to specifically override taxonomy database. Change the default to use a different taxonomy file  
                                   [.tar.gz or directory]. 
  --store_dir            [string]  Where to store initial download of database. [default: store_dir]
  --reference            [string]  Override the FASTA reference file selected by the database_set parameter. It can be a FASTA format reference sequence 
                                   collection or a minimap2 MMI format index. 

Minimap2 Based Options
  --skip_minimap2        [boolean] Skip Minimap2
  --skip_emu             [boolean] Skip EMU
  --minimap2filter       [string]  Filter output of minimap2 by taxids inc. child nodes, E.g. "9606,1404"
  --minimap2exclude      [boolean] Invert minimap2filter and exclude the given taxids instead
  --ref2taxid            [string]  Not required but can be used to specify a  ref2taxid mapping. Format is .tsv (refname  taxid), no header row.
  --split_prefix         [boolean] Enable if using a very large reference with minimap2
  --custom_db            [boolean] Path to custom Minimap2 database
  --emu_db               [string]  Path to EMU database

Output Options
  --out_dir              [string]  Directory for output of all user-facing files. [default: output]

Advanced Options
  --min_len              [integer] Specify read length lower limit
  --min_read_qual        [number]  Minimum read quality.
  --max_len              [integer] Specify read length upper limit
  --threads              [integer] Maximum number of CPU threads to use per workflow task. [default: 2]
  --server_threads       [integer] Number of CPU threads used by the kraken2 server for classifying reads. [default: 2]
  --kraken_clients       [integer] Number of clients that can connect at once to the kraken-server for classifying reads. [default: 2]

!! Hiding 13 params, use --show_hidden_params to show them !!
--------------------------------------------------------------------------------
If you use epi2me-labs/wf-metagenomics for your analysis please cite:

* The nf-core framework
  https://doi.org/10.1038/s41587-020-0439-x
```
## Useful links

* [nextflow](https://www.nextflow.io/)
* [docker](https://www.docker.com/products/docker-desktop)