# Ashes of the Jade Meridian

A first-person 2.5D xianxia game in **Godot 4.7.2 stable**, with a female cultivator, animated 2D characters, textured 3D surroundings, cultivation, and a branching story. The expanded campaign has **100 NPCs, 100 monster species, 1,200 linked quest chapters, and 12 travel regions**.

![A named witness in the world](docs/screenshots/witness.png)

Lin Yue returns to Cloudrest carrying her teacher's sword. Immortal Xu once saved the village, then bound his dead daughter's soul to its mountain. Mei reads the river's memory, Shen reveals the wardens, and Lan asks whether protection grants ownership. Restore three seals, reach Foundation, and choose Mercy or Ascension. Beyond that central story, a hundred witnesses investigate the empire's bindings: sold futures, inherited debts, confiscated dreams, and silence bought with medicine.

## Play

```bash
# In the prepared cloud environment:
source /workspace/.cloud-onboarding/environment.sh
godot --editor --path . --import --quit
godot --path .
```

The cloud environment has checksum-verified **Godot 4.7.2** and **Blender 5.2.2 LTS**. Open `project.godot` and run with F5 in the editor. Interactive play needs a display; automated checks also run headlessly.

| Control | Action |
| --- | --- |
| Enter / left click on title | Begin |
| WASD / mouse | Move / look |
| Shift / Space | Sprint / jump |
| E | Interact with a nearby visible person, blossom, or seal |
| Left click / Q | Weapon attack / spirit palm |
| C, then Enter | Attempt cultivation breakthrough |
| H | Use one moonlotus to heal |
| J | Search and read quest chapters; view active tasks |
| B | NPC lore and monster bestiary |
| M | Travel atlas for all twelve regions |
| R near the southern gate | Rest, restore vitality, renew regional resources and monsters |
| P, then 1 / 2 / 3 | Customize hair / clothing / weapon; mouse also works |
| Escape | Pause / close panel |
| F5 / F9 | Save / load |
| L on title | Continue a saved journey |
| F7 / V | Toggle music / voices |
| 1 / 2 at Xu's final choice | Mercy / Ascension |

Breakthroughs cost **30 / 75 / 140 qi**. Qi Awakening unlocks spirit palm; Foundation plus three restored seals breaks Xu's protection. Bring Mei three moonlotus to start the central story. Renewable camp blossoms keep healing and gathering quests recoverable.

## Campaign and customization

![The searchable chapter reader](docs/screenshots/quest-reader.png)

Each named NPC owns a twelve-chapter arc. Speak beside the author to accept a chapter, carry out its objective, and return for qi and reputation. Up to six chapters may be active. Objectives require actual conversations, gathering, regional travel, rest, or victories over a named monster. Later chapters require their predecessors; rewards are awarded once. The final chapter offers release or inheritance of its binding. The scrollable journal makes every chapter readable, including earlier completed accounts.

The checked corpus contains **2,200,989 words** of quest prose, consequences, and NPC/monster lore. It is **procedurally composed from authored scene templates and linked histories**, with recurring passages and quest patterns. It is not a claim of a million individually written words or a million different narrative events. Counts exclude IDs, metadata, source code, titles, and unused alternate outcomes. Each monster also has a separately authored history, and lore uniqueness is checked after removing the character's name.

Lin Yue defaults to jade robes, loose black hair, and a jade sword. Four hairstyles and four outfits make sixteen independent combinations. Four weapons change reach, cooldown, damage, or spirit-palm strength. New four-pose heroine artwork animates her portrait and preview; her generated weapon appears in first-person view. All selections persist with progression.

![Lin Yue's appearance](docs/screenshots/appearance.png)
![The twelve-region atlas](docs/screenshots/atlas.png)

Regions share the modular valley layout, with different inhabitants, lighting palettes, and three region-specific Blender landmarks. Travel loads the regional cast; camp rest renews its creatures and blossoms. The original Cloudrest seals, guardians, and Xu retain permanent progression. This is a campaign prototype with a large procedural narrative corpus, rather than twelve independently handcrafted terrain maps.

## Assets and evidence

| Library | Included | Source |
| --- | ---: | --- |
| Textured world models | **1,060 distinct GLBs + 1,060 texture PNGs** | Headless Blender: original 1,024 variants plus 36 regional landmarks |
| Animation resources | **2,496 AtlasTexture frames** | Original 1,536 plus 960 new frames from 15 untouched ChatGPT images |
| New live characters | **100 NPCs + 100 monsters** | Four authored poses per character; 24 spare character designs also included |
| Heroine appearances | **16 combinations × 4 new poses** | Dedicated generated atlas, plus four weapon sprites |
| Audio | **113 WAV clips** | Seven synthesized music/effects, six original voices, 100 new NPC greetings |

The image tool returned **1,254 × 1,254** native sheets. New 8×8 sheets provide roughly **155 × 155** frame regions, twice the original 16×16 frame dimensions. A requested 4,096-pixel sheet was not returned; the source images were not upscaled. Frame resources share source PNGs. The number of frames is not a count of separately generated PNG files. Generic eSpeak NG voices provide spoken greetings, not full narration of every chapter.

See [asset provenance](docs/ASSETS.md), [Mermaid architecture and quest diagrams](docs/DESIGN.md), [campaign construction](docs/CAMPAIGN.md), and [the reproduced-defect ledger](docs/audit/README.md).

## Validation and rebuilding

```bash
python3 -m pip install -r tools/requirements.txt
bash tools/check.sh
```

Validation checks all model geometry/embedded textures, image hashes and source rectangles, audio, narrative word counts, lore uniqueness, and quest links. Godot imports the project, runs the world, checks both endings and save migration, replays all 1,200 chains, visits all twelve regions, and verifies a packaged PCK includes the campaign JSON. The audit replays **330 checks**; **327 failed on baseline `4c6493c`**, including repeated manifestations of shared defects. The report does not label these as 327 independent root causes.

To reproduce generated data and Blender assets:

```bash
python3 tools/compile_campaign.py
blender --background --factory-startup --python tools/generate_landmarks.py
python3 tools/register_hires.py
python3 tools/generate_campaign_voices.py  # requires eSpeak NG
```

The original library can also be regenerated using `tools/generate_world.py`, `tools/register_sprites.py`, and `tools/generate_audio.py`. Image registration never draws or edits the generated source artwork.

See [the current chapter, save, and animation revision](docs/REVISION.md) for the 1,200 affected chronology cases and the 16-frame, doubled-resolution Lin Ning pilot. The remaining 9,984 requested frames and full-library resolution upgrade are pending.

CI runs the checks and captures real engine screenshots with Mesa/Xvfb, uploading screenshots and audit results. To capture locally:

```bash
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --path . \
  --rendering-method gl_compatibility --audio-driver Dummy -- --capture
```

Saves use `user://journey.json`, with validated version-three progression and an atomic replacement plus backup. Valid original version-one and version-two saves migrate. Current-region consumption persists across loading. Invalid loads preserve the current journey. Pause freezes movement, gravity, actors, and combat timers; losing focus pauses play. Physical props have collisions, and attacks/interactions require unobstructed sight. Enemy steering slides against obstacles; it is local steering rather than full navigation-mesh pathfinding. Generated sprite alignment can have minor artifacts. Desktop keyboard/mouse play is supported.
