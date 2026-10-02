"""Check actual GLB geometry, UVs, PBR maps, embedded PNGs, and provenance."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def validate(expected_count=None):
    folder = ROOT / "assets/interiors"
    manifest = json.loads((folder / "manifest.json").read_text())
    assert manifest["generator"].startswith("Blender ") and manifest["generator"].endswith(" headless")
    if expected_count is not None: assert len(manifest["models"]) == expected_count
    hashes, ids = set(), set()
    triangles = 0
    for entry in manifest["models"]:
        assert entry["id"] not in ids and entry["path"] == entry["id"] + ".glb"
        ids.add(entry["id"])
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
        assert all(value > 0 for value in entry["size"])
    assert len(manifest["textures"]) == 36
    for entry in manifest["textures"]:
        path = folder / entry["path"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"]
        with Image.open(path) as image:
            assert list(image.size) == manifest["texture_size"]
            assert image.getextrema()[0][0] != image.getextrema()[0][1], "Texture must contain actual surface detail"
    print("INTERIOR_ASSETS_PASS models=%d pbr_textures=%d triangles=%d" % (len(ids), len(manifest["textures"]), triangles))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expect-count", type=int)
    validate(parser.parse_args().expect_count)
