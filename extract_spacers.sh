#!/bin/bash

# Ensure that there are at least three input arguments - the first should be the query file, the second should be the input file, and the third should be the output file
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <query file> <input file> <output file>"
    exit 1
fi

# Rename the arguments for better readability
query_file=$1
input_file=$2
output_file=$3

# Make sure that the output file is empty before adding contents to it
: > "$output_file"

# Extract the query sequence (ignoring the header)
query=$(grep -v "^>" "$query_file")

# Only print out perfect sequence matches, indicating the query sequence in red
grep -v "^>" "$input_file" | grep --color=always -f "$query_file"
printf "\n"

# Create temporary files for the header and housing the BLAST output data for line counting
temp_header=$(mktemp)
temp_blastdata=$(mktemp)
temp_bedfile=$(mktemp)

# Title for matching sequences output section
printf "Sequence Matches\n" >> "$output_file"

# Match the query sequence to the input file using BLAST, filter for perfect matches only
blastn -query "$1" -subject "$input_file" -task blastn-short -outfmt "6 qseqid sseqid pident length qlen sstart send" | awk '$3 == 100 && $4 == $5' > "$temp_blastdata"

# Calculate column widths based on the content of $temp_blastdata
max_qseqid=$(awk -F'\t' '{print length($1)}' "$temp_blastdata" | sort -nr | head -n1)
max_sseqid=$(awk -F'\t' '{print length($2)}' "$temp_blastdata" | sort -nr | head -n1)
max_pident=$(awk -F'\t' '{print length($3)}' "$temp_blastdata" | sort -nr | head -n1)
max_length=$(awk -F'\t' '{print length($4)}' "$temp_blastdata" | sort -nr | head -n1)
max_qlen=$(awk -F'\t' '{print length($5)}' "$temp_blastdata" | sort -nr | head -n1)
max_sstart=$(awk -F'\t' '{print length($6)}' "$temp_blastdata" | sort -nr | head -n1)
max_send=$(awk -F'\t' '{print length($7)}' "$temp_blastdata" | sort -nr | head -n1)

# Dynamically allocate space for each column
printf "%-${max_qseqid}s\t%-${max_sseqid}s\t%-${max_pident}s\t%-${max_length}s\t%-${max_qlen}s\t%-${max_sstart}s\t%-${max_send}s\n" "qseqid" "sseqid" "pident" "length" "qlen" "sstart" "send" > "$temp_header"

# If we got no matches, no headers, spaces, or data is added to the output file.
# Otherwise, we need to add the header and the BLAST output data to the output file.
# As far as spaces is concerned, we only need to add spaces before the header and after the data for best readability.
if [ $(wc -l < "$temp_blastdata") -gt 0 ]; then
    printf "\n" >> "$output_file"
    cat "$temp_header" >> "$output_file"
    cat "$temp_blastdata" >> "$output_file"
    printf "\n" >> "$output_file"
fi

# Outputs the number of matching sequences to stdout
wc -l < "$temp_blastdata"

# Extract all unique sequence IDs
seq_ids=$(awk '{print $2}' "$temp_blastdata" | sort -u)

printf "Spacer Sequences\n\n" >> "$output_file"

# Create a BED file containing sseqid, sstart, and ssend from our BLAST results
for seq_id in "$seq_ids"; do
    awk -v id="$seq_id" '
        BEGIN {OFS="\t"} $2 == id {
            if (NR > 1 && $6 > prev_end) {
                print prev_sseqid, prev_end, $6-1
            }
            prev_sseqid = $2
            prev_end = $7
        }
    ' "$temp_blastdata" > "$temp_bedfile"
done

# Extract the spacer sequences using seqtk
seqtk subseq "$input_file" "$temp_bedfile" >> "$output_file"

# Clean up temporary file
rm "$temp_header"
rm "$temp_blastdata"
rm "$temp_bedfile"
