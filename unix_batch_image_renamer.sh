#!/bin/bash
#
# Script to rename any jpg, jpeg, heic, or mov file to contain its original date and
# also append a unique string with the md5 hash of the file.
#
# Intended to run in Docker (Ubuntu 22.04 → Bash 5.x). Uses Bash 4+ features (e.g. ${var,,}).
#

# Ensure we are running under Bash 4 or newer (required for ${var,,} and other features)
if [ -z "$BASH_VERSION" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: This script requires Bash 4.0 or newer. Current shell/version is incompatible." >&2
    exit 1
fi

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
count_potential_dupes=0

# Clear out any previous run's log file
> potential_duplicates.log

# ==========================================
# PHASE 1: RENAME AND HASH ALL FILES
# ==========================================
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

# ==========================================
# PHASE 2: POST-PROCESSING DUPLICATE CHECK
# ==========================================
echo "Scanning for potential duplicates (files sharing the exact same second)..."

# Find files matching our timestamp pattern, extract the first 19 chars (YYYY-MM-DD_HH-MM-SS), and count occurrences
while read -r count prefix; do
    if [ "$count" -gt 1 ]; then
        ((count_potential_dupes++))
        echo "⚠️  $count files found for timestamp: $prefix" >> potential_duplicates.log

        # Collect group members and classify provenance + stripped JPEG payload.
        # Whole-file size is NOT used (MS padding/XMP/thumb inflate it).
        # Software=Google alone is only a hint; payload hash after -all= is the check.
        group_files=()
        declare -A has_ms has_google payload_md5 payload_size
        tmp_payload_dir=$(mktemp -d)

        for f in "$prefix"*; do
            [ -f "$f" ] || continue
            group_files+=("$f")
            base=$(basename -- "$f")
            has_ms["$base"]=0
            has_google["$base"]=0

            stat -c "  - %n (%s bytes)" "$f" >> potential_duplicates.log
            exiftool -q -q -p '      Nexus [IFD0]: $Make / $Model' "$f" >> potential_duplicates.log

            if LC_ALL=C grep -a -q "MicrosoftPhoto" "$f"; then
                has_ms["$base"]=1
                acquired=$(exiftool -q -q -p '$DateAcquired' "$f")
                echo "      Microsoft [XMP-microsoft]: MicrosoftPhoto marker; DateAcquired=${acquired:-none}" >> potential_duplicates.log
            fi

            software=$(exiftool -q -q -p '$Software' "$f")
            creator=$(exiftool -q -q -p '$CreatorTool' "$f")
            if [ -n "$software" ] || [ -n "$creator" ]; then
                has_google["$base"]=1
                echo "      Google: Software=${software:--} [IFD0]; CreatorTool=${creator:--} [XMP-xmp]" >> potential_duplicates.log
            fi

            # Image bitstream only (metadata stripped). Skip non-JPEG if exiftool fails.
            if [[ "${f,,}" == *.jpg || "${f,,}" == *.jpeg ]]; then
                stripped="$tmp_payload_dir/$base"
                if exiftool -overwrite_original -q -q -all= -o "$stripped" "$f" 2>/dev/null; then
                    payload_size["$base"]=$(stat -c%s "$stripped")
                    payload_md5["$base"]=$(md5deep "$stripped" | awk '{print $1}')
                    echo "      JPEG payload after -all=: ${payload_size[$base]} bytes, md5=${payload_md5[$base]:0:7}…" >> potential_duplicates.log
                fi
            fi
        done

        # --- Suggestion ---
        unique_payloads=$(printf '%s\n' "${payload_md5[@]}" | sort -u | grep -c . || true)
        ms_count=0
        google_count=0
        nongoggle_count=0
        for f in "${group_files[@]}"; do
            base=$(basename -- "$f")
            [ "${has_ms[$base]}" = 1 ] && ((ms_count++))
            if [ "${has_google[$base]}" = 1 ]; then
                ((google_count++))
            else
                ((nongoggle_count++))
            fi
        done

        echo "  Suggestion:" >> potential_duplicates.log
        if [ "${#payload_md5[@]}" -ge 2 ] && [ "$unique_payloads" -eq 1 ]; then
            echo "    Same JPEG payload after metadata strip — tag-only difference; keep any one copy." >> potential_duplicates.log
            echo "    (Whole-file size ignored: MS padding/XMP/thumb make files look bigger.)" >> potential_duplicates.log
        elif [ "$google_count" -gt 0 ] && [ "$nongoggle_count" -gt 0 ] && [ "$unique_payloads" -gt 1 ]; then
            echo "    Likely closer to original (no Google Software/CreatorTool):" >> potential_duplicates.log
            for f in "${group_files[@]}"; do
                base=$(basename -- "$f")
                if [ "${has_google[$base]}" != 1 ]; then
                    note=""
                    [ "${has_ms[$base]}" = 1 ] && note=" — has MicrosoftPhoto (Windows metadata on top, usually no recompress)"
                    echo "      * $base$note" >> potential_duplicates.log
                fi
            done
            echo "    Why: Software=Google is only a hint; confirmed because stripped JPEG" >> potential_duplicates.log
            echo "    payloads DIFFER between the Google-tagged and non-Google files." >> potential_duplicates.log
            echo "    Not decided by whole-file size (MS copies are often larger from padding," >> potential_duplicates.log
            echo "    while payload sizes stay nearly equal — e.g. tens of bytes, not 'bigger image')." >> potential_duplicates.log
        elif [ "$unique_payloads" -gt 1 ]; then
            echo "    Ambiguous: JPEG payloads differ, but tags do not form a clear MS-vs-Google split." >> potential_duplicates.log
            echo "    Inspect manually; do not trust whole-file size alone." >> potential_duplicates.log
        else
            echo "    Insufficient payload data to compare; use tags as weak hints only." >> potential_duplicates.log
        fi

        rm -rf "$tmp_payload_dir"
        echo "" >> potential_duplicates.log
    fi
# The find command ensures we only look at files formatted by this script, ignoring logs or un-renamed files.
done < <(find . -maxdepth 1 -type f -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]_*" -printf "%f\n" | cut -c 1-19 | sort | uniq -c)


# ==========================================
# SUMMARY REPORT
# ==========================================
echo ""
echo "📊 --- Execution Summary --- 📊"
echo "Total files processed:       $count_total"
echo "Files successfully renamed:  $count_renamed"
echo "Skipped (already correct):   $count_skipped_correct"
echo "Skipped (no valid date):     $count_skipped_nodate"
echo "Duplicates overwritten:      $count_overwritten"
if [ "$count_potential_dupes" -gt 0 ]; then
echo "⚠️  Potential dupes found:     $count_potential_dupes sets (See potential_duplicates.log)"
fi
echo "-------------------------------"