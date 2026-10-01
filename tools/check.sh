#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/validate_assets.py
python3 - <<'PY'
import re,subprocess
commands=[
    (['godot','--headless','--path','.','--editor','--import','--quit'],None),
    (['godot','--headless','--path','.','--','--smoke'],'WORLD_SMOKE_PASS'),
    (['godot','--headless','--path','.','--script','tests/run.gd'],'GAMEPLAY_TESTS checks=43 passed=43 failed=0'),
]
for command,marker in commands:
    print('RUN', ' '.join(command),flush=True)
    result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=240)
    errors=re.findall(r'^(?:SCRIPT ERROR|ERROR):.*$',result.stdout,re.M)
    if result.returncode or errors or (marker and marker not in result.stdout):
        print(result.stdout)
        raise SystemExit(result.returncode or 1)
    print(marker or 'GODOT_IMPORT_PASS',flush=True)
PY
