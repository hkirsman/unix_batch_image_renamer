#!/bin/bash

#
# Script to rename any jpg, jpeg, heic file to to contain original date and
# also append unique string with md5 hash of the file.
#

# Lowercase all files.
mmv '*' '#l1'

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
  date_raw=`exiftool -DateTimeOriginal "$file"`
  year=`echo "$date_raw" | cut -c 35-38`
  month=`echo "$date_raw" | cut -c 40-41`
  day=`echo "$date_raw" | cut -c 43-44`
  hour=`echo "$date_raw" | cut -c 46-47`
  minute=`echo "$date_raw" | cut -c 49-50`
  second=`echo "$date_raw" | cut -c 52-53`
  new_file_name="$year-$month-$day"_"$hour-$minute-$second"_"$md5"."$extension"

  # Start renaming but only if file name is correct.
  # We can make the assumption from file name length because the file has
  # either correct name:
  # 2020-07-12_00-17-04_3d52b8b.jpg
  # or not correct name:
  # --_--_0eb7443.jpg
  # So let's assume if file name is longer than 17, we can start renaming it.
  new_file_name_length=${#new_file_name}
  if [ $new_file_name_length -gt 17 ]
  then
    mmv -d "$file" "$new_file_name"
  fi
done
