#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec "$repo_dir/setup.sh" --no-nvim-sync "$@"
