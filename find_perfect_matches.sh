#!/bin/bash
# Make sure there are at least two input arguments - the first should be the input file name and the second should be the output file name
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <query file> <input file> <output file>"
    exit 1
fi

# Rename the objects stored in our arguments to names that make sense
query_file=$1
input_file=$2
output_file=$3

# Ignore the header line and extract the query sequence to look for in the input file
query=$(grep -v "^>" "$query_file")

# Only print out perfect sequence matches, indicating the query sequence in red
grep -v "^>" "$input_file" | grep --color=always -f "$query_file"
printf "\n"

# Create temporary files for the header and housing the BLAST output data for line counting
temp_header=$(mktemp)
temp_blastdata=$(mktemp)

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

# Deletes the temporary file
rm "$temp_blastdata"
