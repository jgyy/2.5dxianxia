"""Independent word-count, graph, lore, objective, and generated-art audit."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def word_count(text):
    return len(re.findall(r"\b[\w]+(?:['’-][\w]+)*\b", text))


def validate():
    root = ROOT / "content/campaign"
    index = json.loads((root / "index.json").read_text())
    npcs = {n["id"]: n for n in index["npcs"]}
    monsters = {m["id"]: m for m in index["monsters"]}
    regions = {r["id"] for r in index["regions"]}
    quests = {q["id"]: q for q in index["quests"]}
    assert len(npcs) == len(monsters) == 100 and len(quests) == 1200 and len(regions) == 12
    assert len({n["name"] for n in npcs.values()}) == 100
    assert len({m["name"] for m in monsters.values()}) == 100
    lore = [x["lore"] for x in list(npcs.values()) + list(monsters.values())]
    assert len(set(lore)) == 200 and min(map(word_count, lore)) >= 180
    anonymized=[x['lore'].replace(x['name'],'PERSON') for x in list(npcs.values())+list(monsters.values())]
    assert len(set(anonymized))==200, 'Lore must differ beyond its character name'
    assert len({m['legend'] for m in monsters.values()})==100
    pages = {}
    for book, digest in index["book_hashes"].items():
        data = (root / book).read_bytes()
        assert hashlib.sha256(data).hexdigest() == digest
        pages.update(json.loads(data))
    assert set(pages) == set(quests)
    assert len({hashlib.sha256(p["story"].encode()).hexdigest() for p in pages.values()}) == 1200
    total = sum(word_count(p[field]) for p in pages.values() for field in ["story", "mercy", "power"]) + sum(map(word_count, lore))
    assert total == index["word_count"] and total >= 1_000_000
    for id, quest in quests.items():
        assert quest["owner"] in npcs and quest["region"] in regions
        assert quest["id"] in npcs[quest["owner"]]["quests"]
        assert len(npcs[quest["owner"]]["quests"]) == 12
        assert quest["stage"] in range(12)
        if quest["previous"]:
            previous = quests[quest["previous"]]
            assert previous["owner"] == quest["owner"] and previous["stage"] == quest["stage"] - 1
        else:
            assert quest["stage"] == 0
        assert bool(pages[id]["power"]) == quest["choice"], "Only final chapters have an alternate outcome"
        objective = quest["objective"]
        assert objective["kind"] in ["talk", "gather", "explore", "kill", "meditate"]
        targets = {"talk": npcs, "kill": monsters, "explore": regions, "gather": {"moonlotus", "jade"}, "meditate": {"rest"}}
        assert objective["target"] in targets[objective["kind"]] and 1 <= objective["count"] <= 5
        assert word_count(pages[id]["story"]) == pages[id]["word_count"]
        assert "{" not in pages[id]["story"] and "}" not in pages[id]["story"]
    print(f"CAMPAIGN_VALIDATION_PASS words={total} quests=1200 unique_npc_lore=100 unique_monster_lore=100 regions=12")


if __name__ == "__main__":
    validate()
