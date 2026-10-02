"""Audit chapter chronology using the same per-chapter cases as the baseline."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def main():
    folder = ROOT / "content/campaign"
    index = json.loads((folder / "index.json").read_text())
    books = {name: json.loads((folder / name).read_text()) for name in index["book_hashes"]}
    cases = []
    for quest in index["quests"]:
        page = books[quest["book"]][quest["id"]]
        passed = "Lin Yue returns through " not in page["story"] and "Lin Yue returns through " in page.get("aftermath", "")
        cases.append({"id": quest["id"], "passed": passed, "reason": "" if passed else "Return appears in unfinished briefing or is missing from aftermath"})
    result = {"checks": len(cases), "passed": sum(c["passed"] for c in cases), "failed": sum(not c["passed"] for c in cases), "root_causes": 1, "cases": cases}
    destination = ROOT / "docs/audit"
    (destination / "chapter-state-results.json").write_text(json.dumps(result, indent=2) + "\n")
    baseline = json.loads((destination / "chapter-state-baseline.json").read_text())
    before = {case["id"]: case["passed"] for case in baseline["cases"]}
    assert set(before) == {case["id"] for case in cases}
    with (destination / "chapter-state-ledger.csv").open("w", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(["chapter", "baseline_passed", "current_passed", "shared_root_cause"])
        for case in cases:
            writer.writerow([case["id"], before[case["id"]], case["passed"], "aftermath-visible-before-completion"])
    print(f"CHAPTER_STATE_AUDIT checks={result['checks']} passed={result['passed']} failed={result['failed']} root_causes=1")
    if result["failed"]:
        raise SystemExit(1)
if __name__ == "__main__":
    main()
