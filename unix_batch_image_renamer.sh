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

# Loop through all jpg, heic, and mov files in the current directory.
find . -maxdepth 1 -type f \( -iname \*.jpg -o -iname \*.heic -o -iname \*.mov \) -print0 |
while IFS= read -r -d '' file; do
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
      md5=`md5deep "$file" | cut -c 1-7`
      new_file_name="${date_formatted}_${md5}.${extension}"
    fi

    # Only rename if the name is actually different, to avoid noise.
    if [ "$file" != "./$new_file_name" ]; then
        echo "Renaming \"$file\" to \"$new_file_name\""
        mmv -d "$file" "$new_file_name"
    fi
  else
    echo "Skipped: $file (no valid date found)"
  fi
done
