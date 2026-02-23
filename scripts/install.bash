#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="${SCRIPT_DIR}/../src/mkworktree.bash"
TARGET_DIR="${HOME}/bin"
TARGET_SCRIPT="${TARGET_DIR}/mkworktree"

if [[ ! -f "${SOURCE_SCRIPT}" ]]; then
  echo "Error: could not find source script at ${SOURCE_SCRIPT}" >&2
  exit 1
fi

mkdir -p "${TARGET_DIR}"
cp "${SOURCE_SCRIPT}" "${TARGET_SCRIPT}"

if chmod +x "${TARGET_SCRIPT}" 2>/dev/null; then
  echo "Installed ${TARGET_SCRIPT}"
else
  echo "Installed ${TARGET_SCRIPT}, but could not set executable permissions." >&2
fi

echo
echo "Add this line to ~/.zshrc to enable completions:"
echo 'source <(mkworktree --print-completion zsh)'
