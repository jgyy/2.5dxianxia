"""Validate committed assets, not just file counts: GLB geometry/materials,
embedded textures, unique hashes, sprite source rectangles, and playable WAVs.
"""
import hashlib
import json
from pathlib import Path
import struct
import wave
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def validate():
    world = ROOT / "assets/world"
    manifest = json.loads((world / "manifest.json").read_text())
    assert len(manifest["models"]) == 1024
    hashes = set()
    for entry in manifest["models"]:
        data = (world / entry["glb"]).read_bytes()
        magic, version, length = struct.unpack_from("<4sII", data)
        assert (magic, version, length) == (b"glTF", 2, len(data))
        size, kind = struct.unpack_from("<I4s", data, 12)
        assert kind == b"JSON"
        gltf = json.loads(data[20:20 + size])
        assert gltf["meshes"] and gltf["materials"] and gltf["textures"] and gltf["images"]
        assert all(image.get("bufferView") is not None for image in gltf["images"]), "GLB must embed its texture"
        assert any(p.get("attributes", {}).get("POSITION") is not None for mesh in gltf["meshes"] for p in mesh["primitives"])
        digest = hashlib.sha256(data).hexdigest()
        assert digest == entry["sha256"]
        hashes.add(digest)
        with Image.open(world / entry["texture"]) as im:
            im.verify()
    assert len(hashes) == 1024, "Model files must be distinct"
    sprites = ROOT / "assets/sprites"
    atlas_manifest = json.loads((sprites / "manifest.json").read_text())
    assert len(atlas_manifest["frames"]) == 1536
    images = {}
    for index, entry in enumerate(atlas_manifest["atlases"]):
        p = sprites / entry["path"]
        assert hashlib.sha256(p.read_bytes()).hexdigest() == entry["sha256"]
        image = Image.open(p)
        assert image.mode == "RGBA"
        assert image.getchannel("A").getextrema()[0] == 0, "Background must be transparent"
        images[index] = image
    frame_hashes = set()
    for entry in atlas_manifest["frames"]:
        assert (sprites / entry["resource"]).is_file()
        x, y, w, h = entry["rect"]
        image = images[entry["sheet"]]
        assert x >= 0 and y >= 0 and x + w <= image.width and y + h <= image.height
        frame = image.crop((round(x), round(y), round(x + w), round(y + h)))
        assert frame.getchannel("A").getextrema()[1] > 0
        digest = hashlib.sha256(frame.tobytes()).hexdigest()
        assert digest == entry["pixel_sha256"]
        frame_hashes.add(digest)
    assert len(frame_hashes) == 1536, "Sprite frames must contain distinct pixels"
    with Image.open(sprites / "weapons.png") as weapons:
        assert weapons.mode == "RGBA" and weapons.getchannel("A").getextrema()[0] == 0
    clips = list((ROOT / "assets/audio").glob("*.wav"))
    assert len(clips) == 113
    for clip in clips:
        with wave.open(str(clip)) as audio:
            assert audio.getnframes() > 1000 and audio.getsampwidth() == 2
    print("ASSET_VALIDATION_PASS 1024 unique textured GLBs / 1024 PNG textures / 1536 unique sprite frames / 4 weapon sprites / 113 WAV clips")


if __name__ == "__main__":
    validate()
