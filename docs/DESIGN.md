# Game and story design

The game asks whether cultivation means becoming powerful enough to keep someone, or wise enough to let them go. Xu is a protector whose refusal to grieve has become the valley's curse. Each NPC offers a different interpretation of his oath. The player's final act determines whether the mountain gains a spring or another immortal keeper.

## Quest flow

```mermaid
flowchart TD
    A[Arrive at Cloudrest] --> B[Mei: gather three moonlotus]
    B --> C[Read the river memory and gain qi]
    C --> D[Shen: discover the binding]
    D --> E[Defeat three meridian wardens]
    E --> F[Restore dawn, rain, and dusk seals]
    C --> G[Gather essence and cultivate]
    G --> H[Reach Foundation]
    F --> I[Confront Immortal Xu]
    H --> I
    I --> J[Defeat Xu and hear his daughter]
    J --> K{Final choice}
    K --> L[Mercy: free her soul and heal the mountain]
    K --> M[Ascension: inherit the binding and its power]
```

The boss checks both requirements on every sword/spirit attack, so entering the final arena early cannot bypass progression. Seals check their own guardian's defeat. Finite essence, herb, seal, and enemy rewards provide enough qi to reach Golden Core. Repeated interactions cannot duplicate collected rewards. Falling or defeat returns the player to Mei with a 15-qi penalty; unlocked realms remain.

## Runtime architecture

```mermaid
flowchart LR
    Main[game.gd: valley, quest, interaction, save] --> Player[player.gd: camera and collision movement]
    Main --> Actors[actor.gd: billboard animation and combat AI]
    Main --> State[cultivation.gd: realms, costs, vitality]
    Main --> HUD[hud.gd: title, status, dialogue, journal]
    Main --> Audio[Music, Effects, Voice buses]
    Actors --> Atlases[ChatGPT atlas frames]
    HUD --> Avatar[Female Lin Yue: hair, outfit, weapon]
    State --> Avatar
    Main --> World[Selected textured GLB instances]
    Main --> Save[user://journey.json]
```

Headless runs load and validate audio resources but skip playback because there is no audible output; graphical runs play the Music, Effects, and Voice buses.

Actor animations select four frames for each state at six frames/second. Enemies approach within their awareness radius, attack with a cooldown, flash when hit, and dissolve when defeated. Sprite3D billboarding preserves the 2D presentation as the first-person camera turns. GLB caches share imported resources across repeated props; distant mountains use scaled textured rock variants. Compatibility rendering keeps the game usable on software OpenGL.

## Female protagonist customization

Lin Yue is female by default. Hair and clothing are independent indices mapping to `hair * 4 + clothing` in a dedicated 16-row generated atlas. Weapons select a separate generated sprite, an attack reach/cooldown, and a damage multiplier. P opens the appearance panel on the title screen or during play; click a choice or use 1/2/3. Save data contains three separate appearance indices and defaults older saves to the female jade-robed sword wielder. Gameplay checks verify independence, row mapping, cycling, changed weapon stats, and persistence.

## Cultivation

```mermaid
stateDiagram-v2
    [*] --> Mortal
    Mortal --> QiAwakening: Spend 30 qi
    QiAwakening --> Foundation: Spend 75 qi
    Foundation --> GoldenCore: Spend 140 qi
    note right of QiAwakening
        Unlock Spirit Palm
        35 stamina, 3 second cooldown
    end note
    note right of Foundation
        Can damage Xu after all 3 seals
    end note
```

Every breakthrough adds 30 maximum vitality and 14 sword damage, and restores vitality. Stamina regenerates while not sprinting; spirit art and sprinting share that resource. Herbs offer a separate healing choice. The final choice is retained in the save and the player can return to explore afterward.

## Asset and validation pipeline

```mermaid
flowchart TD
    Blender[Blender 5.2.2 headless generator] --> Models[1024 GLBs with embedded textures]
    Blender --> Textures[1024 texture PNGs]
    ChatGPT[Six ChatGPT-generated PNG atlases] --> Register[Register atlas regions without editing artwork]
    Register --> Frames[1536 AtlasTexture frame resources]
    Synthesis[Seeded audio synthesis and eSpeak NG] --> WAV[13 WAV clips]
    Models --> Audit[Geometry, texture, uniqueness, hash validation]
    Textures --> Audit
    Frames --> Audit
    WAV --> Audit
    Audit --> Import[Godot 4.7 project import]
    Import --> Tests[World smoke and 43 gameplay checks]
    Tests --> Render[Mesa and Xvfb engine screenshots]
    Render --> CI[Pull request CI artifacts]
```

## Known limits

The valley is small and handcrafted. Enemy steering is direct planar pursuit, not obstacle-aware navigation. The terrain, gates, and valley bounds have collision; many decorative GLB props are visual scenery. Generated atlas cells sometimes contain pose or alignment artifacts; every registered frame is nonempty and distinct, but that check does not judge animation quality. Voices use local synthetic speech rather than acted performances. Saves are versioned locally; there is no cloud-save service.
