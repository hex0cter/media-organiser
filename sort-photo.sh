#!/bin/bash

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

shopt -s globstar nullglob

echo "📂 Organizing photos from: $SOURCE_DIR"
echo "📁 Destination root: $DEST_ROOT"
$FORCE && echo "⚠️  Force mode: Files without EXIF will be included."
$DRY_RUN && echo "🧪 Dry-run mode: No files will really be moved."
echo "==="

# for filepath in "$SOURCE_DIR"/**/*.{jpg,jpeg,png,JPG,JPEG,PNG}; do
find "$SOURCE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | while read -r filepath; do
  echo "Found $filepath ..."
  [ -f "$filepath" ] || continue

  filename=$(basename "$filepath")
  ext="${filename##*.}"

  # Try EXIF
  datetime=$(exiftool -DateTimeOriginal -s3 -d "%Y:%m:%d %H:%M:%S" "$filepath")
  echo "date time from exif is ${datetime}"

  if [ -z "$datetime" ]; then
    if $FORCE; then
      echo "⚠️  No EXIF for $filename — using file creation time"
      datetime=$(stat -f "%SB" -t "%Y:%m:%d %H:%M:%S" "$filepath")
    else
      echo "⏭️  Skipping $filename (no EXIF data)"
      continue
    fi
  fi

  # Parse date parts
  year=$(echo "$datetime" | cut -d':' -f1)
  month_num=$(echo "$datetime" | cut -d':' -f2)
  month_name=$(date -jf "%m" "$month_num" +"%b")
  day=$(echo "$datetime" | cut -d':' -f3 | cut -d' ' -f1)
  time_part=$(echo "$datetime" | cut -d' ' -f2)
  hour=$(echo "$time_part" | cut -d':' -f1)
  min=$(echo "$time_part" | cut -d':' -f2)
  sec_millis=$(echo "$time_part" | cut -d':' -f3)
  millis=$(echo "$sec_millis" | cut -d'.' -f2)
  secs=$(echo "$sec_millis" | cut -d'.' -f1)

  dest_dir="$DEST_ROOT/$year/$month_num-$month_name"
  mkdir -p "$dest_dir"

  base_filename="${year}-${month_num}-${day}_${hour}_${min}_${secs}"
  safe_name=$(safe_filename "$base_filename" "$ext" "$dest_dir")
  dest_path="$dest_dir/$safe_name"

  if $DRY_RUN; then
    echo "🧪 Would move: $filename → $dest_path"
  else
    mv "$filepath" "$dest_path"
    echo "✅ Moved: $filename → $dest_path"
  fi
done

