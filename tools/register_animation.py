"""Register generated animation cells without editing their source image pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/sprites/animation"
def main():
    (BASE / "frames").mkdir(parents=True, exist_ok=True)
    source = BASE / "npc_000.png"
    with Image.open(source) as image:
        assert image.mode == "RGBA" and image.size == (1254, 1254)
        assert image.getchannel("A").getextrema()[0] == 0
        frames = []
        for index in range(16):
            # Source cells double the previous 154.75-pixel registered regions.
            x = index % 4 * image.width / 4 + 2
            y = index // 4 * image.height / 4 + 2
            rect = [x, y, image.width / 4 - 4, image.height / 4 - 4]
            resource = f"frames/npc_000_{index:02}.tres"
            (BASE / resource).write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="res://assets/sprites/animation/npc_000.png" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2(' + ', '.join(map(str, rect)) + ')\nfilter_clip = true\n')
            crop = image.crop((round(x), round(y), round(x + rect[2]), round(y + rect[3])))
            frames.append({"index": index, "state": ["idle", "walk", "attack", "death"][index // 4], "rect": rect, "resource": resource, "pixel_sha256": hashlib.sha256(crop.tobytes()).hexdigest()})
    manifest = {"source": "ChatGPT image generation, existing Lin Ning identity reference", "character": "npc_000", "layout": [4,4], "size": [1254,1254], "sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "frames": frames, "playback_fps": 12, "old_frame_size": [154.75,154.75], "new_frame_size": [309.5,309.5], "requested_additional_frames": 10000, "generated_additional_frames": 16, "remaining_additional_frames": 9984, "status": "pilot; other characters and full sprite-library doubling remain pending"}
    (BASE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("ANIMATION_PILOT_REGISTERED frames=16 region=309.5x309.5 playback_fps=12")
if __name__ == "__main__":
    main()
