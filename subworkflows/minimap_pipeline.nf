import groovy.json.JsonBuilder

OPTIONAL_FILE = file("$projectDir/data/OPTIONAL_FILE")

process unpackTaxonomy {
    label "wfmetagenomics"
    cpus 1
    input:
        path taxonomy
    output:
        path "taxonomy_dir"
    """
    if [[ "${taxonomy}" == *.tar.gz ]]
    then
        mkdir taxonomy_dir
        tar xf "${taxonomy}" -C taxonomy_dir
    elif [[ "${taxonomy}" == *.zip ]]
    then
        mkdir taxonomy_dir
        unzip "${taxonomy}" -d taxonomy_dir
    elif [ -d "${taxonomy}" ]
    then
        mv "${taxonomy}" taxonomy_dir
    else
        echo "Error: taxonomy is neither .tar.gz nor a dir"
        echo "Exiting".
        exit 1
    fi
    """
}

process unpackEmuDB {
    
    label "CHANGE_ME"
    
    tag {"running"}
    
    cpus 1

    input:
        path emu_db
    output:
        path "emu-db"

    script:
    """
    tar xf $emu_db
    """
}

process minimap {
    label "wfmetagenomics"
    cpus params.threads
    input:
        tuple val(meta), path(concat_seqs), path(fastcat_stats)
        path reference
        path refindex
        path ref2taxid
        path taxonomy
    output:
        tuple(
            val(meta),
            path("*.bam"),
            path("*.bam.bai"),
            emit: bam)
        tuple(
            val(meta),
            path("*assignments.tsv"),
            emit: assignments)
        tuple(
            val(meta),
            path("*lineages.txt"),
            emit: lineage_txt)
        tuple(
            val(meta),
            path("${meta.alias}.json"),
            emit: lineage_json)
    script:
        def sample_id = "${meta.alias}"
        def split = params.split_prefix ? '--split-prefix tmp' : ''
    if (!params.custom_db) {
        """
        minimap2 -t "${task.cpus}" ${split} -ax map-ont "${reference}" "${concat_seqs}" \
        | samtools view -h -F 2304 - \
        | workflow-glue format_minimap2 - -o "${sample_id}.minimap2.assignments.tsv" -r "${ref2taxid}" \
        | samtools sort -o "${sample_id}.bam" -
        samtools index "${sample_id}.bam"
        awk -F '\\t' '{print \$3}' "${sample_id}.minimap2.assignments.tsv" > taxids.tmp
        taxonkit \
            --data-dir "${taxonomy}" \
            lineage -R taxids.tmp \
            | workflow-glue aggregate_lineages -p "${sample_id}.minimap2"
        file1=`cat *.json`
        echo "{"'"$sample_id"'": "\$file1"}" >> temp
        cp "temp" "${sample_id}.json"
        """
    } else {
        """
        minimap2 -t "${task.cpus}" ${split} -ax map-ont "${reference}" "${concat_seqs}" \
        | samtools view -h -F 2304 - \
        | samtools sort -o "${sample_id}.bam" -
        samtools index "${sample_id}.bam"
        samtools view ${sample_id}.bam | cut -f 1-3 > "${sample_id}.minimap2.assignments.tsv"
        samtools view -F 4 ${sample_id}.bam | cut -f 3 | sed 's/|.*//' > taxids.tmp
        taxonkit \
            --data-dir "${taxonomy}" \
            lineage -R taxids.tmp \
            | workflow-glue aggregate_lineages -p "${sample_id}.minimap2"
        file1=`cat *.json`
        echo "{"'"$sample_id"'": "\$file1"}" >> temp
        cp "temp" "${sample_id}.json"
        """
    }
}

process EMU {
    label "emu"
    
    conda "${baseDir}/envs/emu.yaml"

    cpus params.threads
    input:
        tuple val(meta), path(concat_seqs), path(fastcat_stats)
        path emu_db
        path taxonomy
    output:
        tuple(
            val(meta),
            path("*.tsv"),
            emit: assignments)
        tuple(
            val(meta),
            path("*lineages.txt"),
            emit: lineage_txt)
        tuple(
            val(meta),
            path("${meta.alias}_emu.json"),
            emit: lineage_json)
    script:
        def sample_id = "${meta.alias}" ?: concat_seqs.getSimpleName
    """
    emu abundance -x map-ont --threads "${task.cpus}" --db "${emu_db}" \
    --keep-files --keep-read-assignments --output-unclassified --output-dir results \
    "${concat_seqs}"
    # Extract taxid to taixds.tmp
    extract_taxid.py results/seqs.fastq_read-assignment-distributions.tsv 
    ln -s results/seqs.fastq_read-assignment-distributions.tsv  "${sample_id}.assignment-distributions.tsv"
    ln -s results/seqs.fastq_rel-abundance.tsv "${sample_id}.rel-abundance.tsv"
    
    taxonkit \
            --data-dir "${taxonomy}" \
            lineage -R taxids.tmp > lineage.tsv
    aggregate_emu_lineage.py -p "${sample_id}.emu" -i lineage.tsv
    file1=`cat *.json`
    echo "{"'"${sample_id}_emu"'": "\$file1"}" >> temp
    cp "temp" "${sample_id}_emu.json"
    """
}


process extractMinimap2Reads {
    label "wfmetagenomics"
    cpus 1
    input:
        tuple val(meta), path("alignment.bam"), path("alignment.bai")
        path ref2taxid
        path taxonomy
    output:
        tuple(
            val(meta),
            path("${meta.alias}.minimap2.extracted.fastq"),
            emit: extracted)
    script:
        def sample_id = "${meta.alias}"
        def policy = params.minimap2exclude ? '--exclude' : ""
    """
    taxonkit \
        --data-dir "${taxonomy}" \
        list -i "${params.minimap2filter}" \
        --indent "" > taxids.tmp
    samtools view -b -F 4 "alignment.bam" > "mapped.bam"
    workflow-glue extract_minimap2_reads \
        "mapped.bam" \
        -r "${ref2taxid}" \
        -o "${sample_id}.minimap2.extracted.fastq" \
        -t taxids.tmp \
        ${policy}
    """
}


process getVersions {
    label "wfmetagenomics"
    cpus 1
    output:
        path "versions.txt"
    script:
    """
    python -c "import pysam; print(f'pysam,{pysam.__version__}')" >> versions.txt
    python -c "import pandas; print(f'pandas,{pandas.__version__}')" >> versions.txt
    fastcat --version | sed 's/^/fastcat,/' >> versions.txt
    minimap2 --version | sed 's/^/minimap2,/' >> versions.txt
    samtools --version | head -n 1 | sed 's/ /,/' >> versions.txt
    taxonkit version | sed 's/ /,/' >> versions.txt
    kraken2 --version | head -n 1 | sed 's/ version /,/' >> versions.txt
    #emu --version | sed 's/ /,/' >> versions.txt
    """
}


process getParams {
    label "wfmetagenomics"
    cpus 1
    output:
        path "params.json"
    script:
        def paramsJSON = new JsonBuilder(params).toPrettyString()
    """
    # Output nextflow params object to JSON
    echo '$paramsJSON' > params.json
    """
}


process makeReport {
    label "wfmetagenomics"
    input:
        path per_read_stats
        path "lineages/*"
        path "versions/*"
        path "params.json"
    output:
        path "wf-metagenomics-*.html", emit: report_html
    script:
        String report_name = "wf-metagenomics-report.html"
        def stats_args = (per_read_stats.name == OPTIONAL_FILE.name) ? "" : "--stats $per_read_stats"
    """   
    workflow-glue report \
        $report_name \
        --versions versions \
        --params params.json \
        $stats_args \
        --lineages lineages \
        --pipeline "minimap"
    """
}

 
// See https://github.com/nextflow-io/nextflow/issues/1636
// This is the only way to publish files from a workflow whilst
// decoupling the publish from the process steps.
process output {
    // publish inputs to output directory
    label "wfmetagenomics"
    publishDir "${params.out_dir}", mode: 'copy', pattern: "*"
    input:
        path fname
    output:
        path fname
    """
    echo "Writing output files"
    """
}


// workflow module
workflow minimap_pipeline {
    take:
        samples
        reference
        refindex
        ref2taxid
        taxonomy
    main:
        outputs = []
        lineages = Channel.empty()
        taxonomy = unpackTaxonomy(taxonomy)
        // Initial reads QC
        per_read_stats = samples.map {
            it[2] ? it[2].resolve('per-read-stats.tsv') : null
        }
        | collectFile ( keepHeader: true )
        | ifEmpty ( OPTIONAL_FILE )
        metadata = samples.map { it[0] }.toList()

        // Run Minimap2
        if (!params.skip_minimap2 && params.classifier == "mapping") {
            mm2 = minimap(
                samples
                | map { [it[0], it[1], it[2] ?: OPTIONAL_FILE ] },
                reference,
                refindex,
                ref2taxid,
                taxonomy
            )

            lineages = lineages.mix(mm2.lineage_json)
        }
        
        if (!params.skip_emu && params.classifier == "mapping") {
            if (params.emu_db.startsWith("https")) {
                emu_db = unpackEmuDB(file(params.emu_db))
            } else {
                emu_db = file(params.emu_db, type: "file", checkIfExists:true)
            }
            
            emu = EMU(
                samples
                | map { [it[0], it[1], it[2] ?: OPTIONAL_FILE ] },
                emu_db,
                taxonomy
            )
            lineages = lineages.mix(emu.lineage_json)
        }
        

        outputs += [
            mm2.bam,
            mm2.assignments,
            mm2.lineage_txt
        ]
        if (params.minimap2filter) {
            mm2_filt = extractMinimap2Reads(
                mm2.bam,
                ref2taxid,
                taxonomy
            )
            outputs += [mm2_filt.extracted]
            }

        // Reporting
        software_versions = getVersions()
        workflow_params = getParams()
        report = makeReport(
            per_read_stats,
            lineages.flatMap { it -> [ it[1] ] }.collect(),
            software_versions.collect(),
            workflow_params
        )

        output(report.report_html.mix(
            software_versions, workflow_params))
    emit:
        report.report_html  // just emit something
}


