#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
qa_root="${TMPDIR:-/tmp}/fazenda-qa"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$qa_root/cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$qa_root/config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$qa_root/data}"
export FAZENDA_QA_DIR="${FAZENDA_QA_DIR:-$qa_root/campaign}"
qa_dir="$FAZENDA_QA_DIR"
mkdir -p "$XDG_CACHE_HOME/fontconfig" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$qa_dir"
godot_bin="${GODOT_BIN:-godot}"
run_checked() {
  local stage="$1"
  shift
  if timeout 180s "$@" > "$qa_dir/$stage.log" 2>&1; then
    if rg 'SCRIPT ERROR|^ERROR:' "$qa_dir/$stage.log"; then
      cat "$qa_dir/$stage.log"
      return 1
    fi
  else
    local command_status=$?
    cat "$qa_dir/$stage.log"
    return "$command_status"
  fi
}
run_checked import "$godot_bin" --headless --editor --path . --import
run_checked campaign "$godot_bin" --headless --path . --script res://tests/run_all.gd
rg 'FAZENDA_TEST_RESULT:' "$qa_dir/campaign.log"
python3 - <<'PY'
import json, os
from pathlib import Path
r=json.loads((Path(os.environ['FAZENDA_QA_DIR']) / 'results.json').read_text())
assert r['passed'] >= 80, 'Required checks did not execute'
assert r['failed'] == 0, r['failures']
assert r['campaign']['completed'] and r['campaign']['clues']==8
assert r['campaign']['currency_injected'] is False
print('Campaign, economy, automation, save and recovery checks completed.')
PY
