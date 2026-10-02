"""Inventory every live sprite identity before generating its twelve views."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/sprites/directional"
GROUPS = ["villagers", "spirit_beasts", "corrupted", "sect_heroes", "ancient_spirits"]


def main():
    originals = json.loads((ROOT / "assets/sprites/manifest.json").read_text())
    hires = json.loads((ROOT / "assets/sprites/hires/manifest.json").read_text())
    campaign = json.loads((ROOT / "content/campaign/index.json").read_text())
    targets = []
    for person in campaign["npcs"] + campaign["monsters"]:
        frame = next(item for item in hires["frames"] if item["id"] == person["id"] + "_0")
        kind = frame["kind"]
        targets.append({"id": person["id"], "name": person["name"], "kind": kind,
                        "reference": f"assets/sprites/hires/{kind}_{frame['character'] // 16}.png",
                        "reference_rect": frame["rect"]})
    for appearance in range(16):
        frame = next(item for item in hires["frames"] if item["id"] == f"hero_{appearance:03}_0")
        targets.append({"id": f"hero_{appearance:03}", "name": "Lin Yue", "kind": "hero",
                        "reference": "assets/sprites/hires/hero_0.png", "reference_rect": frame["rect"]})
    live = {(0, 1): "Mei", (0, 2): "Master Shen", (3, 7): "Lan", (4, 15): "Immortal Xu"}
    live.update({(2, row): "Meridian Warden" for row in [2, 3, 4]})
    live.update({(2 if index % 2 == 0 else 1, index % 14): "Ash Spirit" for index in range(8) if (2 if index % 2 == 0 else 1, index % 14) not in live})
    for (sheet, row), name in sorted(live.items()):
        frame = next(item for item in originals["frames"] if item["sheet"] == sheet and item["character"] == row and item["frame"] == 0)
        targets.append({"id": f"{GROUPS[sheet]}_{row:02}", "name": name, "kind": "core",
                        "reference": f"assets/sprites/atlas_{sheet}.png", "reference_rect": frame["rect"]})
    OUT.mkdir(parents=True, exist_ok=True)
    catalog = {"requested_views": list(range(0, 360, 30)), "targets": targets}
    (OUT / "catalog.json").write_text(json.dumps(catalog, indent=2) + "\n")
    print(f"DIRECTIONAL_CATALOG identities={len(targets)} requested_views={len(targets) * 12}")


if __name__ == "__main__":
    main()
