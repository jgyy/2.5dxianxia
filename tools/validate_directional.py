"""Validate source art, twelve actual regions, transparent detail and registry coverage."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/sprites/directional"


def validate():
    manifest = json.loads((BASE / "manifest.json").read_text())
    catalog = json.loads((BASE / "catalog.json").read_text())
    assert manifest["view_count"] == 12 and manifest["step_degrees"] == 30
    targets = {item["id"] for item in catalog["targets"]}
    ids = set()
    for character in manifest["characters"]:
        assert character["id"] in targets and character["id"] not in ids
        ids.add(character["id"])
        assert [view["angle"] for view in character["views"]] == list(range(0, 360, 30))
        images = []
        for sheet in character["sheets"]:
            path = BASE / sheet["path"]
            assert hashlib.sha256(path.read_bytes()).hexdigest() == sheet["sha256"]
            image = Image.open(path)
            assert image.mode == "RGBA" and list(image.size) == sheet["size"]
            assert image.getchannel("A").getextrema() == (0, 255)
            images.append(image)
        hashes = set()
        assert len(character["states"]["idle"]) == 12
        for index, view in enumerate(character["views"]):
            image = images[view["sheet"]]
            x, y, w, h = view["rect"]
            assert 0 <= x < x + w <= image.width and 0 <= y < y + h <= image.height
            assert h >= (64 if character["kind"] == "monster" else 120) and w >= 35
            pixels = image.crop((x, y, x + w, y + h))
            low_alpha, high_alpha = pixels.getchannel("A").getextrema()
            assert low_alpha == 0 and high_alpha >= 220, (character["id"], index, "transparent gutters and visible figure")
            digest = hashlib.sha256(pixels.tobytes()).hexdigest()
            assert digest == view["pixel_sha256"] and digest not in hashes
            hashes.add(digest)
            resource = (BASE / character["states"]["idle"][index][0]).read_text()
            assert "Rect2(" + ", ".join(map(str, view["rect"])) + ")" in resource
            assert 'path="res://assets/sprites/directional/' + character["sheets"][view["sheet"]]["path"] + '"' in resource
            assert "filter_clip = true" in resource
    print(f"DIRECTIONAL_ASSETS_PASS characters={len(ids)} views={len(ids) * 12} pending_identities={len(targets - ids)}")


if __name__ == "__main__":
    validate()
