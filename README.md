# Photo & Video Organizer

A simple but powerful Bash script to organize photos and videos from a source directory into a structured `YYYY/MM-Month` destination directory based on their metadata.

## Features

-   **Metadata-First Approach**: Uses the most reliable date from the file's metadata (`DateTimeOriginal`, `CreateDate`, etc.).
-   **Smart Fallback**: If no EXIF or metadata date is found, it uses the file system's creation or modification time (whichever is older).
-   **Broad File Support**: Works with common photo (`.jpg`, `.png`) and video (`.mov`, `.mp4`, `.avi`) formats.
-   **Safe Renaming**: Renames files to a `YYYY-MM-DD_HH_MM_SS` format.
-   **No Overwrites**: Automatically adds a numeric suffix (e.g., `_1`, `_2`) to prevent overwriting files with the same timestamp.
-   **Dry Run Mode**: Preview the changes without actually moving any files using the `-n` or `--dry-run` flag.
-   **Platform**: Compatible with macOS.

## Requirements

This script requires `exiftool` to be installed.

-   **On macOS (using Homebrew):**
    ```sh
    brew install exiftool
    ```

## Usage

First, make the script executable:
```sh
chmod +x sort-photo.sh
```

Then, run the script with a source and destination directory:

```sh
./sort-photo.sh [OPTIONS] SOURCE_DIR DEST_DIR
```

### Arguments

-   `SOURCE_DIR`: The directory containing the unsorted photos and videos.
-   `DEST_DIR`: The root directory where the organized files will be moved.

### Options

-   `-f`, `--force`: Process files even if they don't have EXIF data (uses file system time as a fallback).
-   `-n`, `--dry-run`: Show what would be done without actually moving any files.
-   `-h`, `--help`: Display the help message.

### Example

To sort files from `~/Desktop/Unsorted` into `~/Pictures/Organized`, including files without metadata, and perform a dry run first:

```sh
# First, do a dry run to see what will happen
./sort-photo.sh -n -f ~/Desktop/Unsorted ~/Pictures/Organized

# If everything looks good, run it for real
./sort-photo.sh -f ~/Desktop/Unsorted ~/Pictures/Organized
