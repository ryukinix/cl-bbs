#!/bin/sh
# Shell script to download and set up the local Common Lisp HyperSpec symbol map for cl-bbs.
set -e

MAP_DIR="data/HyperSpec/Data"
MAP_FILE="${MAP_DIR}/Map_Sym.txt"
MAP_URL="http://www.lispworks.com/reference/HyperSpec/Data/Map_Sym.txt"

echo "Creating local HyperSpec symbol map directory: ${MAP_DIR}..."
mkdir -p "${MAP_DIR}"

echo "Downloading official Map_Sym.txt from Lispworks..."
if command -v curl >/dev/null 2>&1; then
    curl -sSL "${MAP_URL}" -o "${MAP_FILE}"
elif command -v wget >/dev/null 2>&1; then
    wget -q "${MAP_URL}" -O "${MAP_FILE}"
else
    echo "Error: Neither curl nor wget found in the system!" >&2
    exit 1
fi

echo "Successfully set up local Common Lisp HyperSpec symbol map at ${MAP_FILE}!"
