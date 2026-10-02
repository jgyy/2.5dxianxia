# Asset provenance

The generated art, procedural textures, models, narrative, and original code are supplied under this repository's MIT license. The bundled DejaVu Serif font retains its upstream license in `assets/fonts/LICENSE.txt`.

## Blender world and landmarks

The original `tools/generate_world.py` creates sixteen families × sixty-four seeded variants, totaling **1,024 GLBs and 1,024 32×32 PNG textures**. Families include vegetation, rock, crystals, gates, pavilions, lanterns, bridges, altars, furniture, banners, and ruins. Each model has geometry, materials, and an embedded texture.

The new `tools/generate_landmarks.py` ran in **Blender 5.2.2 LTS**, headlessly. It creates **36 additional GLBs with 36 128×128 textures**, using twelve structural designs and three variations of each: lotus terrace, jade observatory, ferry dock, frost arch, ember forge, ink archive, meteor dais, moonwell, thunder obelisk, dream orchard, bone ossuary, dawn sanctuary. Regional structures use different assemblies of mesh geometry. Their manifests contain model and texture SHA-256 hashes. The complete library therefore has **1,060 distinct GLBs and 1,060 authored texture PNGs**. Godot's extracted embedded texture copies are ignored and are not counted as new artwork.

Runtime caches instantiate selected resources. Physical props have colliders; trees use trunk cylinders, and structures use component boxes. Distant mountain silhouettes remain scenery outside the playable area.

## ChatGPT image generation

The original six transparent 1,254×1,254 sheets use 16×16 frame layouts, yielding 1,536 registered frames. A separate 2×2 weapon sheet supplies the sword, saber, fan, and staff.

This expansion generated **fifteen additional transparent sheets** directly with ChatGPT image generation: seven NPC sheets, seven monster sheets, and one heroine sheet. Each uses an 8×8 layout. Two characters occupy each row, with four consecutive poses per character: idle, walk, attack, and death or injury. The heroine sheet supplies sixteen hair/outfit combinations in the same four-pose arrangement.

NPC prompts named sixteen distinct archetypes per sheet across artisan, academy, harbor, frost, forge, archive, and pilgrimage themes. Monster prompts named the corresponding sixteen species per sheet, across beasts, undead, river spirits, frost creatures, fire creatures, dream entities, and celestial creatures. All prompts requested full figures, consistent identities within a pose sequence, transparent gutters, no text, and no background. The heroine prompt specified loose black hair, high ponytail, silver bob, twin buns, combined with jade robes, ivory hanfu, crimson tunic, and indigo robes.

The requested 4,096×4,096 dimensions were advisory; the tool returned **1,254×1,254** images. They are committed unchanged. New cells are approximately 157 pixels wide, with registered regions approximately 155 pixels after gutters, compared with approximately 78-pixel original cells. That improves frame resolution by roughly two in each dimension. No artificial upscaling or procedural replacement art was used.

`tools/register_hires.py` registers **960 new AtlasTexture resources** without modifying PNG pixels. Of the 224 new NPC/monster designs, 200 are assigned to the live campaign and 24 remain available as spare designs. The additional 64 frames belong to the heroine's sixteen appearances. Combined with the retained original resources, the library contains **2,496 distinct registered animation frames**. Counts refer to frames sharing twenty-one source character sheets, rather than separate image-generation calls for every frame.

New actors visibly alternate poses, show their authored attack pose during a windup, flash when hit, and fade using the authored death pose. Core actors retain the original sixteen-frame animations. Images can have minor grid alignment and anatomy artifacts; the independent validator proves hashes, nonempty distinct cells, and valid mappings, rather than aesthetic perfection.

## Sound and speech

The original seven music/effect WAVs use deterministic waveform/noise synthesis, and the original six voices use eSpeak NG. `tools/generate_campaign_voices.py` adds **100 synthetic spoken NPC greetings**, with individual names, roles, and places, varying generic voices, pitch, and speed. It does not clone anyone's voice. `assets/audio/campaign_voices.json` contains the exact text, source, and hashes.

The total is **113 WAVs**: seven music/effect clips and 106 spoken clips. Every chapter remains readable; the million-word corpus is not fully voiced. F7 toggles music, V toggles voice. Effects use twelve reusable playback channels. Headless validation loads assets and skips inaudible playback.

## Screenshots

`docs/screenshots/` contains real Godot 4.7 renders using Mesa software OpenGL under Xvfb. `--capture` records the title, valley, shrine, cultivation, appearance, academy, atlas, bestiary, witness, and chapter reader. CI regenerates and uploads screenshots, together with the audit results. These screenshots are engine captures, not image-generated mockups.
