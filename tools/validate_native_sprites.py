"""Inspect real native-frame pixels and mappings; optionally require full coverage."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

from register_native_sprites import BASE, MINIMUM, ROOT, inventory


def validate(require_complete=False):
    manifest = json.loads((BASE / "manifest.json").read_text())
    expected = set(inventory())
    assert manifest["minimum_frame_size"] == [MINIMUM, MINIMUM]
    assert manifest["requested_frames"] == len(expected)
    resources, hashes = set(), set()
    for frame in manifest["frames"]:
        assert frame["resource"] in expected and frame["resource"] not in resources
        resources.add(frame["resource"])
        path = (BASE / frame["path"]).resolve()
        assert path.is_relative_to(BASE.resolve()) and path.is_file()
        assert hashlib.sha256(path.read_bytes()).hexdigest() == frame["sha256"]
        assert (ROOT / frame["reference"]).is_file()
        assert frame["method"] == "native image regeneration; no resampling or pixel editing"
        with Image.open(path) as image:
            assert image.mode == "RGBA" and list(image.size) == frame["size"]
            assert min(image.size) >= MINIMUM, frame["resource"]
            assert image.getchannel("A").getextrema() == (0, 255)
            assert hashlib.sha256(image.tobytes()).hexdigest() == frame["pixel_sha256"]
            assert frame["pixel_sha256"] not in hashes, "Repeated drawings are not new native frames"
            hashes.add(frame["pixel_sha256"])
    assert manifest["completed_frames"] == len(resources)
    assert manifest["remaining_frames"] == len(expected - resources)
    assert (manifest["status"] == "complete") == (resources == expected)
    if require_complete:
        assert resources == expected, f"{len(expected - resources)} sprite frames still need native artwork"
    print(f"NATIVE_SPRITES_PASS completed={len(resources)} remaining={len(expected - resources)} minimum={MINIMUM}x{MINIMUM}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-complete", action="store_true")
    validate(parser.parse_args().require_complete)
