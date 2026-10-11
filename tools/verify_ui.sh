#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
qa_root="${TMPDIR:-/tmp}/fazenda-qa"
export FAZENDA_QA_DIR="${FAZENDA_QA_DIR:-$qa_root/campaign}"
export FAZENDA_UI_QA_DIR="${FAZENDA_UI_QA_DIR:-$qa_root/ui}"
mkdir -p "$FAZENDA_UI_QA_DIR"
if [ ! -f "$FAZENDA_QA_DIR/campaign_final.json" ]; then
  printf 'Run bash tools/verify.sh first, using the same FAZENDA_QA_DIR.\n' >&2
  exit 1
fi
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  printf 'Rendered checks require a desktop display or Xvfb.\n' >&2
  exit 1
fi
if timeout 180s bash run.sh --audio-driver "${FAZENDA_AUDIO_DRIVER:-Dummy}" --script res://tests/ui_smoke.gd > "$FAZENDA_UI_QA_DIR/run.log" 2>&1; then
  if rg 'SCRIPT ERROR|^ERROR:' "$FAZENDA_UI_QA_DIR/run.log"; then cat "$FAZENDA_UI_QA_DIR/run.log"; exit 1; fi
else
  command_status=$?
  cat "$FAZENDA_UI_QA_DIR/run.log"
  exit "$command_status"
fi
rg 'FAZENDA_UI_RESULT:' "$FAZENDA_UI_QA_DIR/run.log"
python3 - <<'PY'
import json, os
from pathlib import Path
r=json.loads((Path(os.environ['FAZENDA_UI_QA_DIR'])/'results.json').read_text())
assert r['passed']>=130, 'Required rendered checks did not execute'
assert r['failed']==0, r['failures']
assert len(r['captures'])>=19
print('Rendered input, UI, focus, fishing, memory and postgame checks completed.')
PY
