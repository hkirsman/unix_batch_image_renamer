#!/bin/bash
#
# Script to rename any jpg, jpeg, heic, or mov file to contain its original date and
# also append a unique string with the md5 hash of the file.
#
# Intended to run in Docker (Ubuntu 22.04 → Bash 5.x). Uses Bash 4+ features (e.g. ${var,,}).
#

# Check if the keep-file-names parameter is passed
KEEP_FILENAMES=false
if [ "$1" = "keep-file-names" ]; then
    KEEP_FILENAMES=true
    echo "Keep original filenames mode activated"
fi

# Lowercase all files first. This helps catch any edge cases.
mmv '*' '#l1' || echo "Warning: Lowercase conversion failed or no files to convert."

# Normalize jpeg file extensions.
mmv '*.jpeg' '#1.jpg' > /dev/null 2>&1

# Initialize stats counters
count_total=0
count_renamed=0
count_skipped_correct=0
count_skipped_nodate=0
count_overwritten=0

# Loop through all jpg, heic, and mov files in the current directory.
# Note: Using process substitution < <() instead of a pipe | to prevent
# the while loop from running in a subshell, which would lose our counter values!
while IFS= read -r -d '' file; do
  ((count_total++))
  file_base=$(basename -- "$file")
  extension="${file_base##*.}"
  original_name="${file_base%.*}"

  # Force the extension to be lowercase (Bash 4+; Docker image has Bash 5.x).
  extension="${extension,,}"

  # Use exiftool to extract and format the date directly (suppressing warnings with -q -q)
  # First, try the tag common for images.
  date_formatted=$(exiftool -q -q -p '$DateTimeOriginal' -d "%Y-%m-%d_%H-%M-%S" "$file")

  # If that tag was empty, try the tag common for videos.
  if [ -z "$date_formatted" ]; then
      date_formatted=$(exiftool -q -q -p '$CreateDate' -d "%Y-%m-%d_%H-%M-%S" "$file")
  fi

  # Check if we successfully found a date.
  if [ ! -z "$date_formatted" ]; then
    if $KEEP_FILENAMES; then
      new_file_name="${date_formatted}_${original_name}.${extension}"
    else
      md5=$(md5deep "$file" | cut -c 1-7)
      new_file_name="${date_formatted}_${md5}.${extension}"
    fi

    # Check if file needs renaming, overwriting, or skipping
    if [ "$file_base" = "$new_file_name" ]; then
        ((count_skipped_correct++))
    else
        # If target file already exists, it's an overwrite/deduplication
        if [ -e "$new_file_name" ]; then
            echo "Duplicate found! Overwriting/deduplicating \"$file\" into \"$new_file_name\""
            ((count_overwritten++))
        else
            echo "Renaming \"$file\" to \"$new_file_name\""
            ((count_renamed++))
        fi

        # Perform the actual rename
        mmv -d "$file" "$new_file_name"
    fi
  else
    echo "Skipped: $file (no valid date found)"
    ((count_skipped_nodate++))
  fi
done < <(find . -maxdepth 1 -type f \( -iname \*.jpg -o -iname \*.heic -o -iname \*.mov \) -print0)

# Print Summary Report
echo ""
echo "📊 --- Execution Summary --- 📊"
echo "Total files processed:       $count_total"
echo "Files successfully renamed:  $count_renamed"
echo "Skipped (already correct):   $count_skipped_correct"
echo "Skipped (no valid date):     $count_skipped_nodate"
echo "Duplicates overwritten:      $count_overwritten"
echo "-------------------------------"
