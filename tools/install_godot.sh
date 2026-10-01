#!/usr/bin/env bash
set -euo pipefail
# Official stable binary, verified against the official release checksum list.
destination="${1:-/tmp/jade-godot}"
mkdir -p "$destination"
cd "$destination"
release=https://github.com/godotengine/godot-builds/releases/download/4.7-stable
archive=Godot_v4.7-stable_linux.x86_64.zip
curl --fail --silent --show-error --location "$release/SHA512-SUMS.txt" -o SHA512-SUMS.txt
curl --fail --silent --show-error --location "$release/$archive" -o "$archive"
python3 - "$archive" <<'PY'
import hashlib,pathlib,sys,zipfile
p=pathlib.Path(sys.argv[1])
expected=[line.split()[0] for line in pathlib.Path('SHA512-SUMS.txt').read_text().splitlines() if line.split()[-1].lstrip('*')==p.name]
assert len(expected)==1, 'Missing official checksum'
assert hashlib.sha512(p.read_bytes()).hexdigest()==expected[0], 'Godot checksum mismatch'
with zipfile.ZipFile(p) as archive:
    assert archive.namelist()==['Godot_v4.7-stable_linux.x86_64']
    archive.extractall('.')
PY
chmod +x Godot_v4.7-stable_linux.x86_64
ln -sf Godot_v4.7-stable_linux.x86_64 godot
./godot --version
