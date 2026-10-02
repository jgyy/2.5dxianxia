# Game and story design

Cultivation asks what a person becomes responsible for when she gains power. Xu's wish to keep his daughter becomes a mountain's prison. Lin Yue may release her or inherit the binding. The regional campaign examines the same question through a hundred witnesses and the records their institutions tried to erase.

## Central plot

```mermaid
flowchart TD
    A[Lin Yue arrives] --> B[Mei: gather three moonlotus]
    B --> C[Read the river memory]
    C --> D[Shen and Lan reveal Xu's binding]
    D --> E[Defeat three wardens]
    E --> F[Restore meridian seals]
    C --> G[Cultivate to Foundation]
    F --> H[Confront Xu]
    G --> H
    H --> I{Final choice}
    I --> J[Mercy: release his daughter]
    I --> K[Ascension: inherit the binding]
    J --> L[Continue the regional accounts]
    K --> L
```

## Regional quest lifecycle

```mermaid
stateDiagram-v2
    [*] --> Available
    Available --> Active: Meet author and accept
    Active --> Active: Matching world event
    Active --> Available: Abandon
    Active --> Ready: Objective count reached
    Ready --> Completed: Return to author and claim
    Completed --> NextChapter: Unlock prerequisite
    NextChapter --> Active: Accept next account
    Completed --> [*]: Final chapter choice recorded
```

Each of the hundred NPCs has twelve chapters. Up to six are active. Rewards require the author; event targets must match. Rest renews regional resources and monsters, while permanent core progress persists. Unfinished chapters show the briefing. Completed chapters reveal the aftermath and chosen consequence. Regional pages use lazy loading, keeping two books cached. See [campaign construction and measurement](CAMPAIGN.md) for procedural-content limitations.

## Runtime and persistence

```mermaid
flowchart LR
    Game[game.gd: world and event routing] --> Player[player.gd: first-person physics]
    Game --> Actors[actor.gd: 2D billboards and collision AI]
    Game --> Core[cultivation.gd: realms and core plot]
    Game --> Campaign[campaign.gd: chapters and regional cast]
    Campaign --> Books[Twelve JSON chapter books]
    Game --> Panel[campaign_panel.gd: search and scroll reader]
    Panel --> Campaign
    Game --> HUD[hud.gd: status and female appearance]
    Game --> GLB[Shared GLBs and regional landmarks]
    Game --> Audio[Music, voice, twelve effect channels]
    Game --> Codec[save_codec.gd: validate before mutation]
    Codec --> Save[Atomic version-three save plus backup]
```

Actors combine Sprite3D billboards with CharacterBody3D collision. Core actors use sixteen-frame animations; the Lin Ning pilot uses sixteen doubled-resolution poses at 12 FPS, while other campaign characters use four generated poses with visible alternation, windup, hurt flash, and death fade. Ranged attacks require sight, charge creatures telegraph a rush, leech creatures regain vitality on a successful hit, and melee creatures approach physically. Local steering slides around obstacles; full navigation meshes are outside this prototype.

Pause freezes gravity, movement, enemy updates, and combat timers. Focus loss opens a pause panel. Player attacks and interactions require unobstructed sight through the world collision layer. Respawn resets motion, aim, and pursuers. World models are cached and reused. The compatibility renderer supports Mesa software OpenGL.

## Cultivation and female appearance

```mermaid
stateDiagram-v2
    [*] --> Mortal
    Mortal --> QiAwakening: Spend 30 qi
    QiAwakening --> Foundation: Spend 75 qi
    Foundation --> GoldenCore: Spend 140 qi or choose Ascension
    note right of QiAwakening
        Spirit Palm: 35 stamina
        Three-second cooldown
    end note
    note right of Foundation
        Three seals permit damage to Xu
    end note
```

Breakthroughs restore health, add thirty maximum vitality, and increase weapon damage. Sprinting and spirit palm share stamina. Lin Yue has independent hair, clothing, and weapon indices. Four hairstyles × four outfits map to sixteen generated appearances; four first-person weapons change combat stats. Appearance, stamina, orientation, core progress, campaign progress, region, and current-region consumption persist in validated saves. Version-one and version-two saves migrate.

## Asset and CI pipeline

```mermaid
flowchart TD
    Blender[Blender 5.2.2 headless] --> GLB[1061 GLBs and texture PNGs]
    Images[ChatGPT image generation] --> Frames[2512 registered animation frames]
    Authoring[Scene templates and 100 creature histories] --> Compiler[Campaign compiler]
    Compiler --> Content[1200 chapters and 200 lore entries]
    Speech[eSpeak NG and effect synthesis] --> WAV[113 WAVs]
    GLB --> Validate[Independent asset and content validation]
    Frames --> Validate
    Content --> Validate
    WAV --> Validate
    Validate --> Godot[Godot 4.7.2 import]
    Godot --> Audit[Baseline regression replays and gameplay checks]
    Audit --> Pack[Export PCK and run packaged campaign]
    Pack --> Capture[Real Mesa and Xvfb screenshots]
    Capture --> CI[PR CI evidence artifact]
```

[The audit ledger](audit/README.md) separates failure cases from underlying defect families. CI completes all quest chains and checks both endings, actual regional interactions, persistence, and packaged content. Committed screenshots come from the running engine. See [the current revision and its remaining bulk asset work](REVISION.md).
