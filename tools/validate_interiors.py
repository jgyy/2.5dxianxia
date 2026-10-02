"""Check actual GLB geometry, UVs, PBR maps, embedded PNGs, and provenance."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def validate(expected_count=None):
    folder = ROOT / "assets/interiors"
    manifest = json.loads((folder / "manifest.json").read_text())
    assert manifest["generator"].startswith("Blender ") and manifest["generator"].endswith(" headless")
    if expected_count is not None: assert len(manifest["models"]) == expected_count
    hashes, ids, models = set(), set(), {}
    triangles = 0
    for entry in manifest["models"]:
        assert entry["id"] not in ids and entry["path"] == entry["id"] + ".glb"
        ids.add(entry["id"])
        models[entry["id"]] = entry
        payload = (folder / entry["path"]).read_bytes()
        digest = hashlib.sha256(payload).hexdigest()
        assert digest == entry["sha256"] and digest not in hashes
        hashes.add(digest)
        assert struct.unpack_from("<4sII", payload) == (b"glTF", 2, len(payload))
        size, kind = struct.unpack_from("<I4s", payload, 12)
        assert kind == b"JSON"
        gltf = json.loads(payload[20:20 + size])
        assert gltf["meshes"] and gltf["materials"] and gltf["images"]
        binary_offset = 20 + size
        binary_size, binary_kind = struct.unpack_from("<I4s", payload, binary_offset)
        assert binary_kind == b"BIN\x00"
        binary = payload[binary_offset + 8:binary_offset + 8 + binary_size]
        for image in gltf["images"]:
            assert "bufferView" in image and "uri" not in image
            view = gltf["bufferViews"][image["bufferView"]]
            offset = view.get("byteOffset", 0)
            assert binary[offset:offset + 8] == b"\x89PNG\r\n\x1a\n"
        for material in gltf["materials"]:
            pbr = material["pbrMetallicRoughness"]
            assert "baseColorTexture" in pbr and "metallicRoughnessTexture" in pbr and "normalTexture" in material
        for mesh in gltf["meshes"]:
            for primitive in mesh["primitives"]:
                assert all(key in primitive["attributes"] for key in ["POSITION", "NORMAL", "TEXCOORD_0"])
                indices = gltf["accessors"][primitive["indices"]]
                assert indices["count"] > 0 and indices["count"] % 3 == 0
                triangles += indices["count"] // 3
        assert all(math.isfinite(value) and value > 0 for value in entry["size"])
        assert all(math.isfinite(value) for value in entry["center"])
    assert len(manifest["textures"]) == 36
    for entry in manifest["textures"]:
        path = folder / entry["path"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"]
        with Image.open(path) as image:
            assert list(image.size) == manifest["texture_size"]
            assert image.getextrema()[0][0] != image.getextrema()[0][1], "Texture must contain actual surface detail"
    layouts = json.loads((ROOT / "content/city/interiors.json").read_text())["rooms"]
    city = json.loads((ROOT / "content/city/cloudrest.json").read_text())
    expected_rooms = {(building["style"], floor) for building in city["buildings"] for floor in range(len(building["floors"]))}
    rooms, used, instances = set(), set(), 0
    for room in layouts:
        key = (room["style"], room["floor"])
        assert key in expected_rooms and key not in rooms, "Every city floor has one layout"
        rooms.add(key)
        assert len(room["props"]) >= 16
        for prop in room["props"]:
            assert prop["id"] in ids
            used.add(prop["id"])
            instances += 1
            position, scale = prop["position"], prop.get("scale", 1)
            assert len(position) == 3 and all(math.isfinite(value) for value in position)
            assert math.isfinite(scale) and 0 < scale <= 2
            angle = math.radians(prop.get("yaw", 0))
            assert math.isfinite(angle)
            model = models[prop["id"]]
            center, size = model["center"], model["size"]
            x = position[0] + scale * (center[0] * math.cos(angle) + center[2] * math.sin(angle))
            z = position[2] + scale * (-center[0] * math.sin(angle) + center[2] * math.cos(angle))
            half_x = scale * (abs(math.cos(angle)) * size[0] + abs(math.sin(angle)) * size[2]) / 2
            half_z = scale * (abs(math.sin(angle)) * size[0] + abs(math.cos(angle)) * size[2]) / 2
            top = position[1] + scale * (center[1] + size[1] / 2)
            bottom = position[1] + scale * (center[1] - size[1] / 2)
            assert x - half_x > -7.9 and x + half_x < 7.9, (key, prop, "side wall")
            assert z - half_z > -6.9 and z + half_z < 6.9, (key, prop, "front/back wall")
            assert bottom >= -.03 and top < 3.82, (key, prop, "floor/ceiling")
            # The stairs and the continuous approach to each NPC stay clear.
            assert x + half_x < 1.7, (key, prop, "stair approach")
            if prop.get("solid", True):
                assert x + half_x < -1.75, (key, prop, "resident approach")
    assert rooms == expected_rooms and used == ids
    print("INTERIOR_ASSETS_PASS models=%d pbr_textures=%d triangles=%d rooms=%d instances=%d" % (len(ids), len(manifest["textures"]), triangles, len(rooms), instances))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expect-count", type=int)
    validate(parser.parse_args().expect_count)
