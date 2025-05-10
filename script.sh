#!/usr/bin/env bash

# References:
# - https://nikitabobko.github.io/AeroSpace/commands#list-windows
# - https://www.alfredapp.com/help/workflows/inputs/script-filter/json/

AERO_DELIM=":::DELIM:::"

result_json=$( \
  aerospace list-windows --all --format "%{app-pid}${AERO_DELIM}%{window-id}${AERO_DELIM}%{app-name}${AERO_DELIM}%{window-title}" | \
  awk -F "${AERO_DELIM}" '{
    appPid = $1
    windowId = $2
    appName = $3
    windowTitle = $4

    # Get appPath using ps
    ps_cmd = "ps -o comm= -p " appPid
    appPath = "" # Default to empty string
    if ((ps_cmd | getline line) > 0) {
      appPath = line
    }
    close(ps_cmd)

    # Calculate bundlePath
    bundlePath = appPath
    # Replicates bash: ${appPath%%\.app*}.app
    sub(/\.app.*/, "", bundlePath) # Remove .app and anything after
    bundlePath = bundlePath ".app" # Append .app

    # Output fields separated by NUL, one record per line
    printf "%s%c%s%c%s%c%s%c%s%c%s\n", appPid, 0, windowId, 0, appName, 0, windowTitle, 0, appPath, 0, bundlePath
  }' | \
  jq --raw-input --slurp '
    # Split the entire input by newlines, then filter out empty lines
    split("\n")
    | map(select(length > 0))
    # For each line, split by NUL character to get fields
    | map(split("\u0000") | {
        # Assign fields to an object based on their order from awk
        # .[0] is appPid, .[1] is windowId, .[2] is appName,
        # .[3] is windowTitle, .[4] is appPath, .[5] is bundlePath
        "title": .[2], # appName
        "subtitle": .[3], # windowTitle
        "match": (.[2] + " | " + .[3]), # appName | windowTitle
        "arg": .[1], # windowId
        "icon": {
          "type": "fileicon",
          "path": .[5] # bundlePath
        }
      })
    # Wrap the resulting array of objects into the final structure
    | {items: .}
  '
)

echo "$result_json"

if [ -n "$DEBUG" ]; then
  echo ""
  echo "--- END: $(date) ---"
  echo ""
fi
