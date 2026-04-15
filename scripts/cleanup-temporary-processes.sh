#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "pwsh is required to run cleanup-temporary-processes.ps1 on macOS or Linux." >&2
  exit 1
fi

exec pwsh -NoProfile -File "$SCRIPT_DIR/cleanup-temporary-processes.ps1" "$@"
