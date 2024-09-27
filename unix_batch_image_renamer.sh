#!/bin/bash

#
# Script to rename any jpg, jpeg, heic file to to contain original date and
# also append unique string with md5 hash of the file.
#

# Check if the keep-file-names parameter is passed
KEEP_FILENAMES=false
if [ "$1" = "keep-file-names" ]; then
    KEEP_FILENAMES=true
    echo "Keep original filenames mode activated"
fi

# Lowercase all files.
mmv '*' '#l1' || echo "Warning: Lowercase conversion failed or no files to convert."

# Normalize jpeg file extensions.
mmv '*.jpeg' '#1.jpg' > /dev/null 2>&1

# Better foreach for looping through files:
# https://askubuntu.com/questions/343727/filenames-with-spaces-breaking-for-loop-find-command/343753#343753
#
# Looping through files by checking multiple extensions.
# https://unix.stackexchange.com/questions/15308/how-to-use-find-command-to-search-for-multiple-extensions
find . -maxdepth 1 -type f \( -iname \*.jpg -o -iname \*.heic \) -print0 |
while IFS= read -r -d '' file; do
  md5=`md5deep "$file" | cut -c 1-7`
  file_base=$(basename -- "$file")
  extension="${file_base##*.}"
  original_name="${file_base%.*}"

  date_raw=`exiftool -DateTimeOriginal "$file"`
  year=`echo "$date_raw" | cut -c 35-38`
  month=`echo "$date_raw" | cut -c 40-41`
  day=`echo "$date_raw" | cut -c 43-44`
  hour=`echo "$date_raw" | cut -c 46-47`
  minute=`echo "$date_raw" | cut -c 49-50`
  second=`echo "$date_raw" | cut -c 52-53`

  date_formatted="$year-$month-$day"_"$hour-$minute-$second"
  if [ "$date_formatted" != "--_--" ]; then
    if $KEEP_FILENAMES; then
      new_file_name="${date_formatted}_${original_name}.${extension}"
    else
      new_file_name="${date_formatted}_${md5}.${extension}"
    fi

    mmv -d "$file" "$new_file_name"
  else
    echo "Skipped: $file (no valid date found)"
  fi
done
