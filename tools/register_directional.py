"""Register transparent source rectangles without changing generated PNG pixels."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/sprites/directional"


def row_bounds(image, rows):
    alpha = image.getchannel("A").point(lambda value: 255 if value > 24 else 0)
    bounds = [0]
    for row in range(1, rows):
        center = round(row * image.height / rows)
        radius = round(image.height / rows * .16)
        candidates = range(center - radius, center + radius + 1)
        bounds.append(min(candidates, key=lambda y: (alpha.crop((0, y, image.width, y + 1)).histogram()[255], abs(y - center))))
    return bounds + [image.height]


def register():
    spec = json.loads((BASE / "sources.json").read_text())
    catalog = {item["id"]: item for item in json.loads((BASE / "catalog.json").read_text())["targets"]}
    manifest = {"source": spec["source"], "view_count": 12, "step_degrees": 30, "characters": []}
    (BASE / "frames").mkdir(exist_ok=True)
    for character in spec["characters"]:
        assert character["id"] in catalog and len(character["views"]) == 12
        images, sheets = [], []
        for sheet in character["sheets"]:
            path = BASE / sheet["path"]
            image = Image.open(path)
            assert image.mode == "RGBA" and image.getchannel("A").getextrema()[0] == 0
            images.append(image)
            sheets.append({**sheet, "size": list(image.size), "row_bounds": row_bounds(image, sheet["layout"][1]), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        frames, views = [], []
        for angle, (sheet_index, cell) in enumerate(character["views"]):
            sheet, image = sheets[sheet_index], images[sheet_index]
            columns, rows = sheet["layout"]
            assert 0 <= cell < columns * rows
            left, top = round((cell % columns) * image.width / columns), sheet["row_bounds"][cell // columns]
            right, bottom = round((cell % columns + 1) * image.width / columns), sheet["row_bounds"][cell // columns + 1]
            # Tight source rectangles normalize height/feet across different native grids.
            alpha = image.getchannel("A").crop((left, top, right, bottom))
            bounds = alpha.point(lambda value: 255 if value > 24 else 0).getbbox()
            assert bounds is not None
            x, y = max(left, left + bounds[0] - 2), max(top, top + bounds[1] - 2)
            end_x, end_y = min(right, left + bounds[2] + 2), min(bottom, top + bounds[3] + 2)
            rect = [x, y, end_x - x, end_y - y]
            resource = f"frames/{character['id']}_{angle:02}.tres"
            (BASE / resource).write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="res://assets/sprites/directional/' + sheet["path"] + '" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2(' + ', '.join(map(str, rect)) + ')\nfilter_clip = true\n')
            digest = hashlib.sha256(image.crop((x, y, end_x, end_y)).tobytes()).hexdigest()
            frames.append([resource])
            views.append({"angle": angle * 30, "sheet": sheet_index, "cell": cell, "rect": rect, "pixel_sha256": digest})
        manifest["characters"].append({"id": character["id"], "name": catalog[character["id"]]["name"],
                                        "kind": catalog[character["id"]]["kind"], "sheets": sheets,
                                        "states": {"idle": frames}, "views": views})
    (BASE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"DIRECTIONAL_REGISTERED characters={len(manifest['characters'])} views={len(manifest['characters']) * 12}")


if __name__ == "__main__":
    register()
