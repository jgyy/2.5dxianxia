"""Register ChatGPT-generated atlases as 1,536 AtlasTexture sprites.

No recoloring or procedural replacement artwork: frame resources reference
rectangles in the image-generated PNGs. Pillow only inspects their pixels.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/sprites"
GROUPS = ["villagers", "spirit_beasts", "corrupted", "sect_heroes", "ancient_spirits", "female_protagonist"]


def row_boundaries(image):
    """Inspect transparent gutters to accommodate small generated grid drift.

    Only source rectangles change; the generated PNG is never edited.
    Use the first eight idle/walk columns so attack effects do not hide gutters.
    """
    alpha = image.getchannel("A")
    width, height = image.size
    scores = []
    for y in range(height):
        pixels = list(alpha.crop((0, y, width // 2, y + 1)).getdata())
        scores.append(sum(pixels) / (255 * len(pixels)))
    smooth = [(scores[max(0, y - 1)] + scores[y] + scores[min(height - 1, y + 1)]) / 3 for y in range(height)]
    bounds = [0]
    for row in range(1, 16):
        center = round(row * height / 16)
        candidates = range(max(0, center - 20), min(height, center + 21))
        bounds.append(min(candidates, key=lambda y: smooth[y] + abs(y - center) * .0002))
    return bounds + [height]


def main():
    frames_dir = OUT / "frames"
    frames_dir.mkdir(exist_ok=True)
    manifest = {"source": "ChatGPT image generation", "layout": [16, 16], "character_rows": 96, "female_appearance_combinations": 16, "frames_per_character": 16, "animation": {"idle": [0, 3], "walk": [4, 7], "attack": [8, 11], "death": [12, 15]}, "atlases": [], "frames": []}
    for sheet, group in enumerate(GROUPS):
        path = OUT / f"atlas_{sheet}.png"
        image = Image.open(path).convert("RGBA")
        width, height = image.size
        baseline = json.loads((ROOT / "docs/audit/sprite-resolution-baseline.json").read_text())
        original = next(a for a in baseline["atlases"] if a["path"] == str(path.relative_to(ROOT)))
        scale = width / original["size"][0]
        assert height / original["size"][1] == scale
        bounds = [b * scale for b in original["row_boundaries"]]
        manifest["atlases"].append({"path": path.name, "group": group, "size": [width, height], "row_boundaries": bounds, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        for row in range(16):
            for column in range(16):
                x, y, w, h = column * width / 16, bounds[row] + 2 * scale, width / 16, bounds[row + 1] - bounds[row] - 4 * scale
                name = f"{group}_{row:02}_{column:02}"
                resource = f'''[gd_resource type="AtlasTexture" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/sprites/atlas_{sheet}.png" id="1"]

[resource]
atlas = ExtResource("1")
region = Rect2({x}, {y}, {w}, {h})
filter_clip = true
'''
                (frames_dir / f"{name}.tres").write_text(resource)
                pixels = image.crop((round(x), round(y), round(x + w), round(y + h)))
                alpha = pixels.getchannel("A")
                assert alpha.getextrema()[1] > 0, f"Empty frame {name}"
                manifest["frames"].append({"id": name, "sheet": sheet, "character": row, "frame": column, "resource": f"frames/{name}.tres", "rect": [x, y, w, h], "pixel_sha256": hashlib.sha256(pixels.tobytes()).hexdigest()})
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"SPRITE_LIBRARY_COMPLETE {len(manifest['frames'])} atlas frame resources")


if __name__ == "__main__":
    main()
