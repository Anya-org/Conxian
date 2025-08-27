#!/bin/bash
set -e

# Get the directory of this script, which is /scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# Go up one level to the project root
PROJECT_ROOT="$SCRIPT_DIR/.."
STACKS_DIR="$PROJECT_ROOT/stacks"

# Check if node_modules exists in the clarinet-wrapper directory
if [ ! -d "$STACKS_DIR/clarinet-wrapper/node_modules" ]; then
  echo "Node modules not found in stacks/clarinet-wrapper directory. Installing dependencies with 'npm install'..."
  (cd "$STACKS_DIR/clarinet-wrapper" && npm install)
fi

# Check if node_modules exists in the project root
if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
  echo "Node modules not found in project root. Installing dependencies with 'npm install'..."
  (cd "$PROJECT_ROOT" && npm install)
fi
