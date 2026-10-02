# Cloudrest city

Lantern Avenue extends south from the original valley camp. It has **12 enterable buildings, 36 furnished floors, 24 physical staircases, and 40 named residents**. The city is available in Cloudrest (`region_00`). Travel through the existing atlas returns to the valley camp, where the city gate is open.

Press **N** for the searchable directory. Search by building, district, resident, occupation, or floor name. Mark an entrance to display a gold sign and its distance in the world. Mark the same address again to clear it. Every entrance faces the cross lane on the south side of its building. The right-hand staircase connects all three floors.

![Lantern Avenue in the real Godot engine](screenshots/city.png)

| Building | Ground floor | Second floor | Third floor |
| --- | --- | --- | --- |
| Lotus Lantern Inn | Welcome hall | Guest rooms | Travelers' study |
| Riverroot Clinic | Treatment hall | Herbal dispensary | River laboratory |
| Listening Rain Teahouse | Tea room | Poetry salon | Quiet meditation room |
| Ember Crane Forge | Public forge | Weapon workshop | Cultivators' practice room |
| Nine Clouds Silk House | Cutting room | Pattern loft | Fitting room |
| Unbound Ink Archive | Public reading room | Witness records | Unsealed collection |
| Jade Brush Talisman Hall | Brush workshop | Apprentices' classroom | Ward research room |
| Wayfarer Guildhouse | Dispatch hall | Caravan office | Route council |
| Falling Star Observatory | Instrument gallery | Star chart room | Meridian study |
| Moonwell Bathhouse | Public baths | Steam room | Healing retreat |
| House of Returning Bells | Memorial hall | Resonance workshop | Bellkeepers' sanctuary |
| Open Oath Courthouse | Petition hall | Mediation room | Public council |

A resident occupies every floor. Gate guide Tao Jun, market gardener Min Qiu, ferry courier Rao Wen, and storyteller Deng Yi live along the avenue. All 40 residents have personal dialogue and a second interaction: advice, healing, rest, tea, appearance choices, cultivation, chapter reading, regional travel, or the city directory. Press **E**, then **1** or **2**. Enter or Escape closes the conversation.

Their short personal accounts are authored in `content/city/cloudrest.json`. City residents reuse 40 distinct existing high-resolution NPC sprite designs with four animated poses each. The expansion adds no new source character artwork or generated animation frames. The campaign's 100 authors and 1,200 chapter chains remain separately available. City rest restores vitality and stamina; it does not advance an objective requiring rest at the valley camp or generate qi rewards.

![The inn's ground-floor resident](screenshots/city-interior.png)
![The observatory's third-floor resident](screenshots/city-upper-floor.png)
![A resident's personal account](screenshots/city-dialogue.png)

The district is assembled from timber, plaster, framed windows, raised eaves, lanterns, shop banners, and furnishings, using Godot geometry and existing world textures. Shared meshes and materials keep the modular architecture reproducible. It is a playable city prototype with a regular street plan and themed furnishings; residents stay at their addresses rather than following daily schedules.

Stairs use visible wooden treads over continuous ramp colliders so the existing first-person controller can climb without jumping. Upper floor slabs leave the stairwell open. Doors, furniture, glass, walls, and floors have physical collisions. Sight and proximity checks prevent interactions through walls or between floors. Dialogue uses the existing pause behavior.

Save version four allows positions throughout the Cloudrest city, including its upper rooms, and retains version-three regional resource and monster consumption. Versions one through three still migrate. Coordinates outside the world, or city coordinates belonging to another region, are rejected before any journey state changes. Travel disables city geometry and resident collisions and closes the southern gate; returning restores access. Loading and rest retain exactly one instance of each city resident.

`tests/city.gd` performs **448 checks** in the actual engine. It walks through all twelve doors, climbs and descends both staircases in every building, exits onto the street, talks to all 40 residents, selects their stories and services, verifies walls and floors block sight, searches and marks addresses, restores an upper-floor save, migrates a version-three save, and checks regional travel and camp rest. It runs in `tools/check.sh`, alongside the existing campaign, combat, ending, save, and packaged-world suites.

The standard `--capture` mode also renders city evidence in CI. For city screenshots alone:

```bash
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --path . \
  --rendering-method gl_compatibility --audio-driver Dummy -- --capture-city
```

The earlier bulk animation request remains incomplete as documented in [REVISION.md](REVISION.md); this city expansion does not change that outstanding scope.
