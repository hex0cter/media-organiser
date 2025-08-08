#!/bin/bash
# IMPORTANT: This script requires exiftool to be installed.
# Install it via Homebrew: `brew install exiftool`
# This script organizes photos and videos into year/month directories based on their EXIF data.
# If EXIF data is not available, it uses the file creation time.
# !!!NOTE!!! This script only works on macOS due to the use of `stat` command options.

# --- Functions ---

print_help() {
  echo "Usage: $0 [OPTIONS] SOURCE_DIR DEST_DIR"
  echo ""
  echo "Options:"
  echo "  -f, --force       Include files without EXIF data (uses file creation time)"
  echo "  -n, --dry-run     Show what would be done without actually moving files"
  echo "  -h, --help        Show this help message"
  exit 0
}

error_exit() {
  echo "❌ $1"
  exit 1
}

check_exiftool() {
  if ! command -v exiftool >/dev/null 2>&1; then
    error_exit "exiftool not found. Please install it with: brew install exiftool"
  fi
}

safe_filename() {
  local base="$1"
  local ext="$2"
  local dir="$3"
  local i=1
  local new="$base.$ext"
  while [ -e "$dir/$new" ]; do
    new="${base}_$i.$ext"
    ((i++))
  done
  echo "$new"
}

# --- Parse arguments ---

FORCE=false
DRY_RUN=false

POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)
      FORCE=true
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      print_help
      ;;
    -*)
      echo "Unknown option: $1"
      print_help
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

# Restore positional args
set -- "${POSITIONAL[@]}"

# --- Validate args ---

[ $# -ne 2 ] && print_help

SOURCE_DIR="$1"
DEST_ROOT="$2"

[ ! -d "$SOURCE_DIR" ] && error_exit "Source directory not found: $SOURCE_DIR"
mkdir -p "$DEST_ROOT" || error_exit "Failed to create destination root: $DEST_ROOT"

check_exiftool

# --- Main processing ---

# shopt -s globstar nullglob

echo "📂 Organizing photos from: $SOURCE_DIR"
echo "📁 Destination root: $DEST_ROOT"
$FORCE && echo "⚠️  Force mode: Files without EXIF will be included."
$DRY_RUN && echo "🧪 Dry-run mode: No files will really be moved."
echo "==="

find "$SOURCE_DIR" -type f -not -name "._*" \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
  -iname "*.mov" -o -iname "*.mp4"  -o -iname "*.m4v" -o -iname "*.avi" -o \
  -iname "*.mts" -o -iname "*.wmv"  -o -iname "*.dat" \
  \) -print0 | while IFS= read -r -d '' filepath; do

  [ -f "$filepath" ] || continue

  echo "Found $filepath ..."
  filename=$(basename "$filepath")
  ext="${filename##*.}"

  # Try EXIF, using -G to help find tags in different metadata groups.
  # Prioritize the main EXIF/QuickTime dates, but fall back to the general ModifyDate.
  datetime_parts=$(exiftool -q -p '$DateTimeOriginal# > $QuickTime:CreateDate# > $Keys:CreationDate# > $CreateDate# > $MediaCreateDate# > $TrackCreateDate# > $ModifyDate#' -d "%Y %m %b %d %H %M %S" "$filepath")

  if [ -z "$datetime_parts" ]; then
    datetime_parts=$(exiftool -q -m -api RequestAll=3 -p '${DateTimeOriginal;QuickTime:CreateDate;Keys:CreationDate;CreateDate;MediaCreateDate;TrackCreateDate;ModifyDate}' -d "%Y %m %b %d %H %M %S" "$filepath")
  fi

  if [ -z "$datetime_parts" ]; then
    if $FORCE; then
      echo "⚠️  No EXIF for $filename — using file creation time"
      birth_ts=$(stat -f "%B" "$filepath")
      modify_ts=$(stat -f "%m" "$filepath")

      # Use the older (smaller) of the two timestamps
      if [[ "$birth_ts" -lt "$modify_ts" ]]; then
        timestamp=$birth_ts
      else
        timestamp=$modify_ts
      fi

      read -r year month_num month_name day hour min secs < <(date -r "$timestamp" "+%Y %m %b %d %H %M %S")
    else
      echo "⏭️  Skipping $filename (no EXIF data)..."
      continue
    fi
  else
      read -r year month_num month_name day hour min secs <<< "$datetime_parts"
  fi

  month_num=$(printf "%02d" "$((10#$month_num))")
  dest_dir="$DEST_ROOT/$year/$month_num-$month_name"
  mkdir -p "$dest_dir"

  base_filename="${year}-${month_num}-${day}_${hour}_${min}_${secs}"
  safe_name=$(safe_filename "$base_filename" "$ext" "$dest_dir")
  dest_path="$dest_dir/$safe_name"

  if $DRY_RUN; then
    echo "🧪 Would move: $filepath → $dest_path"
  else
    mv -i "$filepath" "$dest_path"
    echo "✅ Moved: $filepath → $dest_path"
  fi
done
