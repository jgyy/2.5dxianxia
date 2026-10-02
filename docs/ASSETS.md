# Asset provenance

The generated art, procedural textures, models, narrative, and original code are supplied under this repository's MIT license. The bundled DejaVu Serif font retains its upstream license in `assets/fonts/LICENSE.txt`.

## Blender world and landmarks

The original `tools/generate_world.py` creates sixteen families × sixty-four seeded variants, totaling **1,024 GLBs and 1,024 32×32 PNG textures**. Families include vegetation, rock, crystals, gates, pavilions, lanterns, bridges, altars, furniture, banners, and ruins. Each model has geometry, materials, and an embedded texture.

The new `tools/generate_landmarks.py` ran in **Blender 5.2.2 LTS**, headlessly. It creates **36 additional GLBs with 36 128×128 textures**, using twelve structural designs and three variations of each: lotus terrace, jade observatory, ferry dock, frost arch, ember forge, ink archive, meteor dais, moonwell, thunder obelisk, dream orchard, bone ossuary, dawn sanctuary. Regional structures use different assemblies of mesh geometry. Their manifests contain model and texture SHA-256 hashes. These two batches contain **1,060 distinct GLBs and 1,060 authored texture PNGs**. Godot's extracted embedded texture copies are ignored and are not counted as new artwork.

Runtime caches instantiate selected resources. Physical props have colliders; trees use trunk cylinders, and structures use component boxes. Distant mountain silhouettes remain scenery outside the playable area.

## Textured city interiors

`tools/generate_interiors.py` ran with **Blender 4.3.2, in background mode**, to create **40 original GLBs**. This is the Blender version installed in the current generation environment; the earlier landmark and camp batches used 5.2.2 LTS. The interior library is approximately **44.6 MiB** of GLBs and **2.9 MiB** of shared source texture PNGs. Its common, craft, and special batches can be regenerated separately, with completed batches retained in the manifest.

The models include carved furniture, a curtained canopy bed, filled bookshelves and scroll racks, an apothecary's 25 drawers, tea and medicine tools, a coal hearth and anvil, swords, a threaded loom, silk rolls, writing implements, talisman boards, armillary instruments, a water-filled bath basin, hanging bells and drums, offerings, map routes, court furnishings, and room accents. They use beveled mesh components, meter units, floor origins, UV mapping, and meshes joined by material. The **119,384 triangles** are the sum of the distinct source models, not the count of all repeated instances in the world.

Twelve deterministic material patterns create **36 original 256×256 PNGs**: albedo, roughness, and tangent-space normal maps for each material. Pixels are generated directly in Blender Python from wood grain, textile weave, ceramic bands, jade/stone veins, and engraved metal patterns. The normals derive from the same surface-height patterns. Every model material has all three texture channels. The GLB exporter embeds albedo, normals, and packed metallic/roughness images; no external downloads or texture-only recolored model variants are used for this batch.

`assets/interiors/manifest.json` records the actual Blender version, generator path, SHA-256 hashes, and each model's bounding box in Godot coordinates. The 36 source maps live in `assets/interiors/textures/`. Godot's root-level extracted embedded texture copies remain ignored. The architecture also uses the walnut and stone maps, while the room rugs use their own detailed GLB meshes. Together with the original library, landmarks, and camp beacon, the repository now contains **1,101 distinct GLBs and 1,097 source texture PNGs**.

There are **653 GLB placements across 36 city floors**, at least sixteen per floor. Layout validation checks room bounds and clear routes; the actual engine checks imported materials, entrances, staircases, and interactions with every resident. The packaged smoke test loads all forty scene resources. [CITY.md](CITY.md) documents the room themes, regeneration commands, and real-engine screenshots.

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

`docs/screenshots/` contains real Godot 4.7 renders using Mesa software OpenGL under Xvfb or a headless Xorg display. `--capture` records the title, valley, shrine, cultivation, appearance, academy, atlas, bestiary, witness, and chapter reader, followed by fourteen city views covering the street, furnished rooms, dialogue, and directory. CI regenerates and uploads screenshots, together with the audit results. These screenshots are engine captures, not image-generated mockups.

## Current animation and camp revision

The latest verified toolchain is Godot 4.7.2 and Blender 5.2.2 LTS. A new headless Blender camp beacon adds one textured GLB and one texture PNG, bringing the model library to 1,061. It marks the southern rest camp in every region.

One newly generated 4×4 Lin Ning sheet adds 16 distinct AtlasTexture poses, bringing registered frame resources to 2,512. Its 309.5×309.5 frame regions double her previous 154.75×154.75 regions. This is a pilot for one existing NPC; the full sprite-library upgrade and 9,984 additional requested frames remain pending. No rendering-FPS improvement is claimed. See [revision evidence and the Mermaid flow](REVISION.md).

The eleven earlier revision screenshots were regenerated in the real Godot 4.7.2 renderer, including the camp view. The city furnishing update adds fourteen city screenshots captured in the same renderer.
