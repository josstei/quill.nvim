#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

if ! command -v nvim &> /dev/null; then
    echo "Error: nvim not found in PATH"
    exit 1
fi

echo "Running nvim-quill unit tests..."

nvim --headless --noplugin -u tests/minimal_init.lua \
    -c "PlenaryBustedDirectory tests/unit/ { minimal_init = 'tests/minimal_init.lua' }"

echo ""
echo "Tests completed successfully!"
