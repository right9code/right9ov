!/bin/zsh

# Set the root directory (default: current directory)
ROOT="${1:-.}"

# Recursively find all directories, excluding hidden/special ones
# -mindepth 1: skip the root itself if you don't want a bin there
# Remove -mindepth if you DO want a bin in the top-level folder
find "$ROOT" -type d -not -path "*/\.*" -not -name "_*" -not -name ".*" | while IFS= read -r dir; do
    # Extract just the basename of the directory
    basename=$(basename "$dir")

    # Skip if basename starts with '.' or '_' (extra safety)
    [[ "$basename" == .* || "$basename" == _* ]] && continue

    # Try to extract leading number (digits only at start, before any non-digit)
    if [[ "$basename" =~ ^([0-9]+) ]]; then
        id="${BASH_REMATCH[1]}"
    else
        id="$basename"
    fi

    # Create the unsorted folder
    unsorted_dir="$dir/00 - Unsorted ($id)"
    mkdir -p "$unsorted_dir"
    echo "Created: $unsorted_dir"
done
