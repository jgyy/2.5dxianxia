"""Checkpoint unchanged generated sheets for four cataloged sprite identities."""
import argparse
import json
from pathlib import Path
import shutil

from register_directional import register

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/sprites/directional"


def add_batch(ids, turn, left):
    assert 1 <= len(ids) <= 4
    targets = {item["id"] for item in json.loads((BASE / "catalog.json").read_text())["targets"]}
    assert len(set(ids)) == len(ids) and set(ids) <= targets
    group = ids[0]
    turn_path, left_path = f"sheets/{group}_group_turn.png", f"sheets/{group}_group_left.png"
    shutil.copyfile(turn, BASE / turn_path)
    shutil.copyfile(left, BASE / left_path)
    spec_path = BASE / "sources.json"
    spec = json.loads(spec_path.read_text())
    existing = {item["id"] for item in spec["characters"]}
    assert not existing.intersection(ids), "Finished identities must be explicitly reviewed before replacement"
    for index, id in enumerate(ids):
        row, column = index // 2 * 3, index % 2 * 3
        cells = [(row + y) * 6 + column + x for y in range(3) for x in range(3)]
        helper = index * 3
        views = [[0, cells[0]], [1, helper], [1, helper + 1], [1, helper + 2]]
        views += [[0, cell] for cell in cells[1:]]
        spec["characters"].append({"id": id, "sheets": [{"path": turn_path, "layout": [6, 6]}, {"path": left_path, "layout": [3, 4]}], "views": views})
    spec_path.write_text(json.dumps(spec, indent=2) + "\n")
    register()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ids", nargs="+", required=True)
    parser.add_argument("--turn", type=Path, required=True)
    parser.add_argument("--left", type=Path, required=True)
    args = parser.parse_args()
    add_batch(args.ids, args.turn, args.left)
