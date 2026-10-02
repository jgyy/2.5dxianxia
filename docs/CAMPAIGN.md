# Campaign construction

The central Cloudrest plot follows Lin Yue, Mei, Shen, Lan, Xu, and his daughter. It retains its two playable endings. The expanded world surrounds that story with a hundred named witnesses whose twelve-chapter arcs investigate the costs of imperial and sect bindings.

## Regions and themes

| Region | Investigation | Landmark |
| --- | --- | --- |
| Cloudrest | Dreams carried by a poisoned river | Lotus terraces |
| Jade Academy | Students' futures sold by their school | Examination observatory |
| Lantern Harbor | Debts inherited by passengers | Ferry dock |
| Frost Court | Witnesses frozen instead of heard | Ice arch |
| Ember Forge | Memories burned as fuel | Furnace |
| Whispering Reed | Forbidden names preserved in an archive | Scroll shelves |
| Starfall Steps | A pilgrimage built from fallen stars | Meteor dais |
| Moonwell | Questions their owners regret | Moon well |
| Thunder Pass | A trial repeated by thunder | Storm obelisk |
| Dream Orchard | Dreams confiscated by the empire | Blossom tree |
| Bone Meridian | Dead people forced to pay rent | Ossuary |
| Dawn Sanctuary | The limits of forgiveness | Sun sanctuary |

Regions reuse the modular valley footprint and ground geometry, with distinct palettes, inhabitants, and three structural landmark variants. They are reached through M's travel atlas. Every campaign character appears in a reachable region; tests inspect all 100 NPCs and all 100 monsters.

## Quest rules

Each witness owns an ordered twelve-chapter chain: testimony, roots, travel, confrontation, jade evidence, another witness, rest, a recurring binding, medicine, a second journey, final testimony, and a decisive confrontation. Each chapter names a real target. Six chapters may be active at once; each stage requires the previous stage's completed reward. Acceptance and claiming require proximity to the author, while reading does not.

World events advance matching active objectives. Wrong targets and duplicate reward claims cannot advance or pay again. Kill objectives require the named monster; gathering requires real resource consumption; travel requires the destination; testimony requires speaking to the witness. Rest beside a safe southern gate renews regional creatures and blossoms, allowing tasks requiring repeated manifestations or additional supplies to finish. Permanent core rewards and guardians stay consumed or defeated.

Intermediate consequences describe the evidence collected. Only the final chapter offers release or inheritance. Campaign reputation equals the sum of completed rewards for the witness and is validated on load. Both choices are recorded and readable with the completed account.

## Narrative provenance and measurement

`tools/compile_campaign.py` composes text from authored scene templates, character histories, tasks, places, witnesses, and named creatures. `content/authoring/monster_legends.json` supplies one separately authored history for each of the hundred species. The compiler writes a descriptor index and twelve regional chapter books. This is a large procedural corpus with shared prose and recurring task patterns, not one million handwritten words or unique events.

`tools/validate_campaign.py` independently counts words in quest story text, reachable outcome text, and the 200 lore entries. It excludes IDs, filenames, metadata, titles, source scripts, and authoring inputs. Ordinary words and contractions count using the documented word regex; punctuation does not. Intermediate chapters have one outcome; only final choices have two. The current total is **2,200,989 words** across **1,200 chapters, 100 NPC histories, and 100 monster histories**.

The validator checks every prerequisite and objective target, exact word-count equality, book hashes, unique character names, and distinct lore after removing character names. Unique full-page hashes establish different pages, but do not imply every paragraph is different. Runtime keeps only two regional books in its reading cache; the scrollable, searchable journal loads accounts as selected.

Version-two saves retain active objective counts, completed choices, reputation, current region, the core plot, stamina, appearance, and view orientation. Strict validation precedes mutation. Valid original version-one saves migrate with empty campaign progress. The Linux export preset includes campaign JSON; CI runs a smoke test from the exported PCK to check packaging.
