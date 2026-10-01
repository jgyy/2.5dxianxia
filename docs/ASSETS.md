# Asset provenance

All game art, models, textures, and synthesized sound in this change were created for this repository. The repository's MIT license applies to the original code and generated game content. The bundled DejaVu Serif font retains its separate upstream license in `assets/fonts/LICENSE.txt`.

## 3D world

`tools/generate_world.py` runs in Blender **5.2.2 LTS** in background mode. Sixteen object families have 64 seeded variants each: bamboo, pine, rock, crystal, gate, pavilion, lantern, bridge, shrine, wall, bench, sword, urn, banner, pagoda, and ruin. Their textures are 32 × 32 procedural color/grain PNGs. Every GLB embeds its texture and contains actual mesh geometry and materials. Variants change geometry dimensions, component positions, color, and/or texture grain. They are a modular stylized library, not 1,024 handcrafted hero assets.

`assets/world/manifest.json` records the Blender version, seed, family, variant, source filenames, and SHA-256 for all 1,024 outputs. `tools/validate_assets.py` parses the GLB headers and JSON chunks, checks meshes and embedded textures, validates PNGs, verifies hashes, and requires 1,024 distinct model hashes.

## ChatGPT sprites

Six transparent PNG sprite atlases were generated directly with ChatGPT's image-generation tool. No programmatically drawn or recolored artwork substitutes for these images. The original images are committed unchanged as `assets/sprites/atlas_0.png` through `atlas_5.png`.

The generation prompts specified a square transparent 16-column × 16-row sheet, full-body pixel-art Chinese xianxia figures, no text or scenery, uniform cells, teal/jade/copper colors, and 16 frames per character row (four idle, four movement, four attack, four dissolve). The first five themes were villagers/cultivators, spirit beasts, corrupted monsters, mountain sect heroes, and ancient spirits. Each prompt named 16 character archetypes, such as a lotus healer, sword elder, jade wolf, stone warden, and celestial emperor. A sixth dedicated female protagonist atlas contains four hairstyles × four outfits, each animated across 16 frames. An additional 2 × 2 item atlas supplies four selectable weapons. Her appearance combinations reference those rows directly, and weapons overlay the preview and first-person view.

The requested 2048-pixel size was advisory; the tool returned **1254 × 1254 RGBA** sheets.

`tools/register_sprites.py` creates 1,536 named `.tres` AtlasTexture resources and a manifest with rectangles, PNG hashes, and inspected frame-pixel hashes. It inspects transparent row gutters and adjusts source rectangles to the generated spacing, avoiding pixels from adjacent rows without modifying the original images. Atlas textures share the six PNGs rather than copying or cropping files. The original output grid can have small alignment/pose imperfections; production polish can replace selected rows with more tightly controlled sheets. The running game uses selected rows for its NPCs and enemies, while the full frame library is available in the Godot inspector.

## Sound and voice

`tools/generate_audio.py` creates original effects (steps, sword, hit, hurt, gathering, seal restoration), a looping pentatonic drone/pluck ambience, and six spoken dialogue WAVs. Effects/music use deterministic synthesis with seed `7301`. Voices are generated locally with **eSpeak NG 1.52.0**, varying pitch, speed, and generic English voices. They are explicitly synthetic and do not imitate named people. No external audio samples, music, human voice recordings, or API credentials are required. `assets/audio/manifest.json` contains the spoken script and provenance.

The audio is divided into Music, Effects, and Voice buses. Players can mute music with M and voices with V without losing captions/dialogue. Spoken lines are accompanied by readable dialogue or notices.

## Screenshots

`docs/screenshots/` contains actual Godot 4.7 renders captured with the compatibility renderer and Mesa llvmpipe under Xvfb. They show the title screen, valley, a side shrine, cultivation panel, and female character customization. `--capture` recreates these views, and CI uploads the current run's captures as an artifact.
