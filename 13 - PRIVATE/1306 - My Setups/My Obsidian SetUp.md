1. **Install and Setup `Fit` Plugin**
```githubtoken
githubxxx_pat_11BQ7IPLA0nMxcAotD4NgJ_J3ZWEip5leLm5OdTa37LDA8a8GkXfYR4umxqIZ2kvUVPXWB47MUd82Gc4nB
githubxxx_pat_11BQ7IPLA0hj4HP2tElCbG_L1n0wrpB1shEkFzoRFjij4maA1kujWwGMKXfGiKUkIkLIRBPNAGbERI3eU3
ghpxxx_ImsK6UVxCrs0ZzEOwYd1QuJWlbPWxv2tvSQu
```

2. **Install and Setup `Remotely Save` Plugin**
```koofr key
x5hcz1ygfhi10qvj
```

3. Install and Setup the Terminal Plugin
	- Set Profile : Zsh External

4. **Folder Structure**
	- 00 - Unsorted
	- 01 - BACKEND
		- _DummyPDF
	    - 0101 - Attachments
	    - 0102 - Templates
	    - 0103 - Tags
	    - 0104 - Bases
	    - 0105 - Excalidraw
	    - 0106 - Canvas
	- 03 - WIKI
	    - 0301 - English
	    - 0302 - ComSci
	    - 0303 - Psychology
	    - 0304 - Philosophy
	    - 0305 - Cosmology
	- 05 - ACADEMICS
	    - 0501 - PGT
	    - 0502 - AP
	- 07 - ROUGH NOTES
	- 09 - PWD
	- 11 - PROJECTS
	    - 1101 - Academics
	    - 1102 - Writing
	- 13 - PRIVATE
	    - 1301 - CC
	        - Books
	        - GraphicReads
	        - Anime
	        - AsianDramas
	        - Movies
	        - Shows
	        - Podcasts
	        - Games
	        - Music
	    - 1302 - Journal
	    - 1303 - Writings
	    - 1304 - Quotes
	    - 1305 - JournalArchive

5. Create required folders:
```bash
#!/bin/bash

# Top-level and simple dirs
mkdir -p "00 - Unsorted"

# BACKEND
mkdir -p "01 - BACKEND/_DummyPDF"
mkdir -p "01 - BACKEND/0101 - Attachments"
mkdir -p "01 - BACKEND/0102 - Templates"
mkdir -p "01 - BACKEND/0103 - Tags"
mkdir -p "01 - BACKEND/0104 - Bases"
mkdir -p "01 - BACKEND/0105 - Excalidraw"
mkdir -p "01 - BACKEND/0106 - Canvas"

# WIKI (note: you had a typo: "0105 - Cosmology" → should be "0305")
mkdir -p "03 - WIKI/0301 - English"
mkdir -p "03 - WIKI/0302 - ComSci"
mkdir -p "03 - WIKI/0303 - Psychology"
mkdir -p "03 - WIKI/0304 - Philosophy"
mkdir -p "03 - WIKI/0305 - Cosmology"

# ACADEMICS
mkdir -p "05 - ACADEMICS/0501 - PGT"
mkdir -p "05 - ACADEMICS/0502 - AP"

# ROUGH NOTES
mkdir -p "07 - ROUGH NOTES"

# PWD
mkdir -p "09 - PWD"

# PROJECTS
mkdir -p "11 - PROJECTS/1101 - Academics"
mkdir -p "11 - PROJECTS/1102 - Writing"

# PRIVATE
mkdir -p "13 - PRIVATE/1301 - CC"
mkdir -p "13 - PRIVATE/1301 - CC/Books"
mkdir -p "13 - PRIVATE/1301 - CC/GraphicReads"
mkdir -p "13 - PRIVATE/1301 - CC/Anime"
mkdir -p "13 - PRIVATE/1301 - CC/AsianDramas"
mkdir -p "13 - PRIVATE/1301 - CC/Movies"
mkdir -p "13 - PRIVATE/1301 - CC/Shows"
mkdir -p "13 - PRIVATE/1301 - CC/Podcasts"
mkdir -p "13 - PRIVATE/1301 - CC/Games"
mkdir -p "13 - PRIVATE/1301 - CC/Music"
mkdir -p "13 - PRIVATE/1302 - Journal"
mkdir -p "13 - PRIVATE/1303 - Writings"
mkdir -p "13 - PRIVATE/1304 - Quotes"
mkdir -p "13 - PRIVATE/1305 - JournalArchive"
mkdir -p "13 - PRIVATE/1306 - My Setups"
```

6. **Bash Script to create "00 - Unsorted" Folders**:

```bash
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
```

7. **Setup Desktop themes**:
	- Retroma
	- Velocity
	- Transient
	- Primary

8. **Setup the `css snippets`**:
	- 00 - zen.css
	- 01 - sleek.css
	- 02- sidebar-folder-colors.css
	- 03 - fat-sidebar-folders.css
	- 04 - custon-heading-colors.css
	- 05 - fatheading.css
	- 06 - text-formatting.css
	- 07 - hover-properties.css
	- 08 - hide-popups.css

9. **Basic HOTKEYS SETUP**:
	- [x] ==**Toggle left sidebar**==: Alt + Shift + <-
	- [x] ==**Toggle right sidebar**==: Alt + Shift + ->
	- [x] ==**Toggle ribbon**==:  Alt + Shift + UP
	- [x] ==**Undo Close Tab**==: Ctrl + Shift + T
	- [x] ==**Delete current file**==: Ctrl + Delete
	- [ ] ==**Fold all headings and lists**==: Alt + H
	- [ ] ==**Fold all headings and lists**==: Alt + Shift + H
	- [ ] ==**Toggle Live Preview/Source mode**==: Alt+ Shift + L
	- [ ] ==**Toggle reading view**==: Alt+ Shift + R
	- [ ] **==Search & replace in current file==**: Ctrl + Shift + H
	- [ ] **==Toggle highlight==**: Ctrl + H
	- [ ] **==Toggle strikethrough==**: Ctrl + Shift + 
	- [x] **==Split down==**: Ctrl + Shift + DOWN
	- [x] **==Split right==**: Ctrl + Shift + -> 
	- [x] ==**Change Theme**==: Alt + Ctrl + T
	- [ ] **==Move current file to another folder==**: Alt + M

10. **Setup Plugins**:
	1. Templeter
		- 