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

# Tag suffix for potential-duplicate filenames: _ms, _google, _ms_google, or _untagged.
dupe_tag_suffix() {
  local f="$1"
  local ms=0 google=0
  local software creator

  if LC_ALL=C grep -a -q "MicrosoftPhoto" "$f"; then
    ms=1
  fi

  software=$(exiftool -q -q -p '$Software' "$f")
  creator=$(exiftool -q -q -p '$CreatorTool' "$f")
  if [[ "${software,,}" == *google* ]] || [[ "${creator,,}" == *google* ]]; then
    google=1
  fi

  if [ "$ms" = 1 ] && [ "$google" = 1 ]; then
    echo "_ms_google"
  elif [ "$ms" = 1 ]; then
    echo "_ms"
  elif [ "$google" = 1 ]; then
    echo "_google"
  else
    echo "_untagged"
  fi
}

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
count_moved=0

# Clear out any previous run's log / move-list files
> potential_duplicates.log
printf '%s\n' '# potential duplicate groups (basenames). Blank line separates groups.' > potential_duplicates.txt

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

        # Read-only listing: sizes + where Nexus / Microsoft / Google tags live.
        # No file writes, no metadata stripping.
        group_files=()
        # Re-init empty each group — plain `declare -A x` keeps prior keys.
        declare -A has_ms=() has_google=()

        for f in "$prefix"*; do
            [ -f "$f" ] || continue
            group_files+=("$f")
            base=$(basename -- "$f")
            has_ms["$base"]=0
            has_google["$base"]=0

            echo "$base" >> potential_duplicates.txt

            stat -c "  - %n (%s bytes)" "$f" >> potential_duplicates.log
            exiftool -q -q -p '      Nexus [IFD0]: $Make / $Model' "$f" >> potential_duplicates.log

            if LC_ALL=C grep -a -q "MicrosoftPhoto" "$f"; then
                has_ms["$base"]=1
                acquired=$(exiftool -q -q -p '$DateAcquired' "$f")
                echo "      Microsoft [XMP-microsoft]: MicrosoftPhoto marker; DateAcquired=${acquired:-none}" >> potential_duplicates.log
            fi

            software=$(exiftool -q -q -p '$Software' "$f")
            creator=$(exiftool -q -q -p '$CreatorTool' "$f")
            if [[ "${software,,}" == *google* ]] || [[ "${creator,,}" == *google* ]]; then
                has_google["$base"]=1
                echo "      Google: Software=${software:--} [IFD0]; CreatorTool=${creator:--} [XMP-xmp]" >> potential_duplicates.log
            fi
        done

        # Blank line separates groups in the simple move-list.
        echo "" >> potential_duplicates.txt

        # Tag-only hint (not proof — we no longer compare stripped JPEG payloads).
        google_count=0
        non_google_count=0
        for f in "${group_files[@]}"; do
            base=$(basename -- "$f")
            if [ "${has_google[$base]}" = 1 ]; then
                ((google_count++))
            else
                ((non_google_count++))
            fi
        done

        echo "  Suggestion:" >> potential_duplicates.log
        if [ "$google_count" -gt 0 ] && [ "$non_google_count" -gt 0 ]; then
            echo "    Weak hint — prefer file(s) without Google Software/CreatorTool:" >> potential_duplicates.log
            for f in "${group_files[@]}"; do
                base=$(basename -- "$f")
                if [ "${has_google[$base]}" != 1 ]; then
                    note=""
                    [ "${has_ms[$base]}" = 1 ] && note=" — has MicrosoftPhoto (Windows tags on top; usually no recompress)"
                    echo "      * $base$note" >> potential_duplicates.log
                fi
            done
            echo "    (Tag hint only; confirm visually. Whole-file size is not reliable.)" >> potential_duplicates.log
        else
            echo "    No clear MS-vs-Google tag split; inspect manually." >> potential_duplicates.log
            echo "    (Whole-file size is not reliable — MS padding/XMP inflate it.)" >> potential_duplicates.log
        fi

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
echo "⚠️  Potential dupes found:     $count_potential_dupes sets (See potential_duplicates.log / .txt)"
fi

# ==========================================
# PHASE 3: OPTIONAL MOVE TO duplicates/
# ==========================================
if [ "$count_potential_dupes" -gt 0 ]; then
    do_move=false
    move_env="${MOVE_DUPLICATES,,}"
    case "$move_env" in
        yes|y|1|true)
            do_move=true
            ;;
        no|n|0|false)
            do_move=false
            ;;
        *)
            if [ -r /dev/tty ]; then
                echo ""
                echo "Found $count_potential_dupes potential duplicate set(s)."
                echo "Logged in potential_duplicates.log; move list in potential_duplicates.txt."
                read -r -p "Move all listed files into ./duplicates/ with tag suffixes (_ms/_google/…)? [y/N] " answer </dev/tty
                case "${answer,,}" in
                    y|yes) do_move=true ;;
                esac
            else
                echo "Potential duplicates left in place (no TTY). Set MOVE_DUPLICATES=yes to move non-interactively."
            fi
            ;;
    esac

    if $do_move; then
        mkdir -p duplicates
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip comments and blank lines (group separators).
            [[ -z "$line" || "$line" == \#* ]] && continue
            if [ ! -f "$line" ]; then
                echo "Warning: listed file not found, skipping: $line"
                continue
            fi
            stem="${line%.*}"
            ext="${line##*.}"
            suffix=$(dupe_tag_suffix "$line")
            dest="duplicates/${stem}${suffix}.${ext}"
            if [ -e "$dest" ]; then
                echo "Warning: target already exists, skipping: $dest"
                continue
            fi
            echo "Moving \"$line\" -> \"$dest\""
            mv -- "$line" "$dest"
            ((count_moved++))
        done < potential_duplicates.txt
        echo "Moved to duplicates/:          $count_moved files"
    fi
fi
echo "-------------------------------"
