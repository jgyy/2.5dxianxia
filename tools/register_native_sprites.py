"""Register unchanged native image-generation output for individual sprite frames."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets/sprites"
BASE = SPRITES / "native"
MINIMUM = 1000


def inventory():
    """Include spare frames, legacy art, directional views, and all four weapons."""
    resources = sorted(str(path.relative_to(SPRITES)) for directory in
                       [SPRITES / "frames", SPRITES / "hires/frames",
                        SPRITES / "animation/frames", SPRITES / "directional/frames"]
                       for path in directory.glob("*.tres"))
    return resources + [f"weapons/frames/weapon_{index}.tres" for index in range(4)]


def register(resource, image_path, reference, pose, replace=False):
    assert resource in inventory(), f"Unknown sprite frame: {resource}"
    with Image.open(image_path) as image:
        assert image.mode == "RGBA", "Native sprite requires transparent RGBA artwork"
        assert min(image.size) >= MINIMUM, "Each native frame must be at least 1000 × 1000"
        assert image.getchannel("A").getextrema() == (0, 255)
        bounds = image.getchannel("A").point(lambda value: 255 if value > 24 else 0).getbbox()
        assert bounds and min(bounds[2] - bounds[0], bounds[3] - bounds[1]) >= 100, "Empty or tiny artwork"
        size = list(image.size)
        pixel_hash = hashlib.sha256(image.tobytes()).hexdigest()
    BASE.mkdir(exist_ok=True)
    manifest_path = BASE / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
        "source": "ChatGPT image generation; individual native-resolution regeneration",
        "minimum_frame_size": [MINIMUM, MINIMUM], "frames": []}
    existing = {frame["resource"] for frame in manifest["frames"]}
    assert resource not in existing or replace, "Use --replace for an explicitly reviewed correction"
    manifest["frames"] = [frame for frame in manifest["frames"] if frame["resource"] != resource]
    relative = "images/" + resource.removesuffix(".tres") + ".png"
    destination = BASE / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(image_path, destination)
    manifest["frames"].append({"resource": resource, "path": relative, "size": size,
                             "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
                             "pixel_sha256": pixel_hash, "reference": reference, "pose": pose,
                             "method": "native image regeneration; no resampling or pixel editing"})
    manifest["frames"].sort(key=lambda frame: frame["resource"])
    manifest["requested_frames"] = len(inventory())
    manifest["completed_frames"] = len(manifest["frames"])
    manifest["remaining_frames"] = manifest["requested_frames"] - manifest["completed_frames"]
    manifest["status"] = "complete" if manifest["remaining_frames"] == 0 else "in_progress"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"NATIVE_FRAME_REGISTERED {resource} size={size} remaining={manifest['remaining_frames']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--resource", required=True)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--reference", required=True)
    parser.add_argument("--pose", required=True)
    parser.add_argument("--replace", action="store_true", help="Replace an explicitly reviewed defective frame")
    args = parser.parse_args()
    register(args.resource, args.image, args.reference, args.pose, args.replace)
