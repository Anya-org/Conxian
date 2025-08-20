#!/bin/bash
set -e

# Get the directory of this script, which is /scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# Go up one level to the project root
PROJECT_ROOT="$SCRIPT_DIR/.."
STACKS_DIR="$PROJECT_ROOT/stacks"

# Check if node_modules exists
if [ ! -d "$STACKS_DIR/node_modules" ]; then
  echo "Node modules not found in stacks directory. Installing dependencies with 'npm ci'..."
  (cd "$STACKS_DIR" && npm ci)
fi
