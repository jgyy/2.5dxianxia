#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
python3 "$script_dir/install_toolchain.py" --godot-only --godot-version "${GODOT_VERSION:-4.7.2}" --destination "${1:-/tmp/jade-godot}"
