#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/validate_assets.py
python3 tools/validate_campaign.py
python3 tools/validate_expansion.py
python3 tools/validate_animation.py
python3 tools/validate_interiors.py
python3 tools/audit_chapter_state.py
python3 - <<'PY'
import re,subprocess,tempfile
from pathlib import Path
commands=[
    (['godot','--headless','--path','.','--editor','--import','--quit'],None),
    (['godot','--headless','--path','.','--','--smoke'],'WORLD_SMOKE_PASS'),
    (['godot','--headless','--path','.','--script','tests/run.gd'],'GAMEPLAY_TESTS'),
    (['godot','--headless','--path','.','--script','tests/ascension.gd'],'ENDING_TESTS'),
    (['godot','--headless','--path','.','--script','tests/audit_saves.gd'],'SAVE_AUDIT'),
    (['godot','--headless','--path','.','--script','tests/audit_gameplay.gd'],'GAMEPLAY_AUDIT'),
    (['godot','--headless','--path','.','--script','tests/regressions.gd'],'REGRESSION_TESTS'),
    (['godot','--headless','--path','.','--script','tests/revision.gd'],'REVISION_TESTS'),
    (['godot','--headless','--path','.','--script','tests/directional.gd'],'DIRECTIONAL_TESTS'),
    (['godot','--headless','--fixed-fps','60','--path','.','--script','tests/city.gd'],'CITY_TESTS'),
]
def run(command,marker):
    print('RUN',' '.join(command),flush=True)
    result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=240)
    errors=re.findall(r'^(?:SCRIPT ERROR|ERROR):.*$',result.stdout,re.M)
    if result.returncode or errors or (marker and marker not in result.stdout):
        print(result.stdout)
        raise SystemExit(result.returncode or 1)
    if marker and marker.endswith(('TESTS','AUDIT')):
        line=next(line for line in result.stdout.splitlines() if line.startswith(marker))
        counts=re.search(r'checks=(\d+) passed=(\d+) failed=(\d+)',line)
        assert counts and int(counts[1])>0 and counts[1]==counts[2] and counts[3]=='0',line
        print(line,flush=True)
    else:print(marker or 'GODOT_IMPORT_PASS',flush=True)
for command,marker in commands:run(command,marker)
with tempfile.TemporaryDirectory(prefix='jade-pack-') as tmp:
    pack=str(Path(tmp)/'game.pck')
    run(['godot','--headless','--path','.','--export-pack','Linux Desktop',pack],None)
    run(['godot','--headless','--main-pack',pack,'--','--smoke'],'WORLD_SMOKE_PASS')
    print('PACKAGED_CAMPAIGN_PASS',flush=True)
PY
