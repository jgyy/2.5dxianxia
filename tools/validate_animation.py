"""Validate the authored pose sheet, native dimensions, and the new Blender camp prop."""
import hashlib
import json
from pathlib import Path
import struct
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
def main():
    base = ROOT / "assets/sprites/animation"
    data = json.loads((base / "manifest.json").read_text())
    assert data["image_generated_poses"] == len(data["frames"]) == 16
    assert data["new_frame_size"] == [value * 2 for value in data["old_frame_size"]]
    source = base / "npc_000.png"
    assert hashlib.sha256(source.read_bytes()).hexdigest() == data["sha256"]
    hashes = set()
    with Image.open(source) as image:
        assert image.mode == "RGBA" and list(image.size) == data["size"]
        assert image.getchannel("A").getextrema()[0] == 0
        for entry in data["frames"]:
            x,y,w,h = entry["rect"]
            assert w == h == 309.5 and 0 <= x < x+w <= image.width and 0 <= y < y+h <= image.height
            crop = image.crop((round(x),round(y),round(x+w),round(y+h)))
            assert crop.getchannel("A").getextrema()[1] > 0
            digest = hashlib.sha256(crop.tobytes()).hexdigest()
            assert digest == entry["pixel_sha256"]
            hashes.add(digest)
            resource = (base / entry["resource"]).read_text()
            assert "filter_clip = true" in resource and "Rect2(" + ", ".join(map(str,entry["rect"])) + ")" in resource
    assert len(hashes) == 16
    props = ROOT / "assets/props"
    manifest = json.loads((props / "manifest.json").read_text())
    assert manifest["generator"].startswith("Blender ")
    model = props / "camp_beacon.glb"
    assert hashlib.sha256(model.read_bytes()).hexdigest() == manifest["sha256"]
    payload = model.read_bytes()
    assert struct.unpack_from("<4sII",payload) == (b"glTF",2,len(payload))
    size,kind = struct.unpack_from("<I4s",payload,12)
    assert kind == b"JSON"
    gltf = json.loads(payload[20:20+size])
    assert gltf["meshes"] and gltf["materials"] and gltf["images"]
    assert all("bufferView" in image for image in gltf["images"])
    texture = props / "camp_surface.png"
    assert hashlib.sha256(texture.read_bytes()).hexdigest() == manifest["texture_sha256"]
    print("ANIMATION_AND_CAMP_PASS frames=16 pixel_scale=2 authored_pose_fps=12 new_glbs=1")
if __name__ == "__main__":
    main()
