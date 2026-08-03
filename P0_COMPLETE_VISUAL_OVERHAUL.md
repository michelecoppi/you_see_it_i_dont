# P0 — Complete Visual Overhaul Based on Approved Concept Art

## Objective

Perform a complete graphical and environmental overhaul of the Roblox game
**"YOU SEE IT, I DON'T"** using the approved concept images stored in `docs/images`.

The images are the official visual direction for the project.

The goal is to translate their style, atmosphere, spatial language, materials,
lighting, and UI direction into the existing Roblox implementation while
preserving all current gameplay, networking, persistence, QA, and puzzle logic.

Do not recreate the images pixel-for-pixel.

Treat them as production art-direction references and adapt them to Roblox
Studio, the existing map dimensions, gameplay requirements, and mobile
performance constraints.

---

## Visual reference files

Study all of these files before making changes.

### Global visual direction

- `docs/images/art_direction.png`

This is the primary source of truth for:

- color palette;
- material language;
- lighting;
- architecture;
- anomaly effects;
- interface style;
- visual hierarchy;
- contrast between normal reality and hidden reality.

All other implementation decisions must remain visually consistent with this
reference.

### Lobby

- `docs/images/lobby.png`

Use this reference for:

- overall lobby atmosphere;
- spatial composition;
- portal presentation;
- Anomaly Pad;
- Daily Reactor;
- Reality Mixer;
- Field Briefing;
- leaderboard areas;
- Cosmetics and My Stats access points;
- signage;
- social-space readability.

### Expedition laboratory

- `docs/images/expedition_lab.png`

Use this reference for:

- the expedition shell;
- transitions between puzzle rooms;
- wall architecture;
- floor language;
- room entrances;
- extraction area;
- lighting progression;
- hidden-room presentation;
- environmental atmosphere.

### Puzzle rooms

- `docs/images/rooms/room_signal_chamber.png`
- `docs/images/rooms/room_invisible_floor.png`
- `docs/images/rooms/room_echo_sequence.png`
- `docs/images/rooms/room_frequency_vault.png`
- `docs/images/rooms/room_power_grid.png`

Each image is the primary visual reference for the corresponding procedural
room.

### UI and HUD

- `docs/images/hud_ui.png`

Use this reference for:

- expedition HUD;
- timer;
- phase display;
- role information;
- HOLD INFO panel;
- mobile controls;
- ALT VISION;
- Cosmetics menu;
- My Stats panel;
- buttons, typography, spacing, and panel hierarchy.

### Player roles

- `docs/images/player_roles.png`

Use this reference for visual differentiation between roles.

Do not replace player avatars with fixed custom characters unless the current
architecture explicitly supports it.

Prefer role indicators, wearable accessories, particles, highlights, icons,
interface treatments, or temporary visual effects that remain compatible with
normal Roblox avatars.

### Solo drone

- `docs/images/cosmetic_drone.png`

Use this reference to redesign the Solo companion drone while preserving its
existing gameplay behavior.

### Game icon

- `docs/images/game_icon.png`

This file is a publishing and branding asset.

Do not use it as an in-world texture unless explicitly appropriate.

Verify whether the repository already contains documentation or publishing
configuration for the game icon. If not, document the required manual Roblox
Creator Dashboard step instead of inventing an automated upload system.

---

## Existing systems that must remain functional

Read the full repository and `README.md` before editing.

Pay particular attention to:

- `src/server/LobbyBuilder.luau`
- `src/server/MapBuilder.luau`
- `src/server/RoomGenerator.luau`
- `src/server/SoloDrone.luau`
- `src/server/init.server.luau`
- `src/client/init.client.luau`
- `src/client/SeerClueRenderer.luau`
- `src/client/LobbyController.luau`
- `src/shared/Config.luau`
- `src/shared/Puzzles/`
- all QA, telemetry, persistence, and remote-security modules.

The graphical overhaul must not break:

- Solo portal;
- Group queue for 2–6 players;
- queue countdown;
- Daily Reactor;
- Reality Mixer;
- Field Briefing;
- Anomaly Pad;
- leaderboards;
- Cosmetics;
- My Stats;
- Reality Shards;
- procedural room selection;
- difficulty settings;
- role visibility;
- ALT VISION;
- clue rendering;
- console interaction;
- extraction;
- round timer;
- split times;
- telemetry;
- Studio QA attributes;
- deterministic seeds;
- server-authoritative validation;
- mobile and gamepad controls.

---

## Required work process

### Phase 1 — Repository and art audit

Before editing any file:

1. Inspect all reference images.
2. Inspect the current builders, UI code, and room generation.
3. Identify which visual elements are:
   - already implemented;
   - partially implemented;
   - missing;
   - incompatible with the current gameplay;
   - too expensive for mobile.
4. Produce a concise implementation map in this format:

```text
Reference element
-> Intended Roblox implementation
-> Existing instance or system affected
-> File to modify
-> Gameplay risk
-> Performance risk
```

Do not begin with a blind rewrite.

### Phase 2 — Shared visual system

Create a reusable and centralized visual configuration rather than scattering
hardcoded colors and materials across the project.

Prefer introducing clearly named modules such as:

- `src/shared/VisualConfig.luau`
- `src/shared/Theme.luau`
- `src/shared/UITheme.luau`

Use names appropriate to the existing architecture.

Centralize:

- colors;
- materials;
- transparency;
- glow intensity;
- role colors;
- puzzle colors;
- warning colors;
- typography choices;
- UI corner radius;
- UI stroke properties;
- lighting parameters;
- anomaly effect settings;
- room accent colors.

Avoid duplicating the same visual constants across server and client scripts.

### Phase 3 — Global lighting and atmosphere

Implement a coherent visual baseline based on `art_direction.png`.

Review and configure where appropriate:

- `Lighting`;
- `Atmosphere`;
- `BloomEffect`;
- `ColorCorrectionEffect`;
- `DepthOfFieldEffect`, only if subtle and gameplay-safe;
- ambient colors;
- exposure;
- fog;
- shadow settings;
- environmental reflections.

Requirements:

- puzzle interactions must remain clearly visible;
- the game must not become excessively dark;
- color-based puzzles must retain clear differentiation;
- avoid post-processing that harms mobile readability;
- avoid excessive bloom;
- hidden clues must be visually distinct from normal geometry;
- warning-orange QA visuals must remain clearly distinguishable.

### Phase 4 — Lobby redesign

Use `lobby.png` as the principal reference.

Update the existing lobby while preserving its approximate `108x94` stud
footprint and all gameplay interaction points.

Improve:

- floor composition;
- walls and structural frames;
- ceiling;
- portal presentation;
- circulation routes;
- central visual focus;
- Anomaly Pad;
- Daily Reactor;
- Reality Mixer;
- Field Briefing;
- queue board;
- success and failure leaderboards;
- Cosmetics and My Stats areas;
- signage and labels;
- environmental props;
- lighting zones;
- anomaly-energy details.

Requirements:

- maintain generous movement space;
- preserve accessibility to all interaction prompts;
- do not hide functional objects behind decorative geometry;
- maintain clear Solo and Group portal distinction;
- maintain readable queue information;
- ensure the lobby works with multiple players;
- avoid decorative collision traps;
- do not rename objects referenced by current scripts without updating every
  reference safely.

### Phase 5 — Expedition laboratory redesign

Use `expedition_lab.png`.

Update the laboratory while preserving its approximate `68x150` stud structure
unless the code reveals a safer compatible layout.

Improve:

- structural shell;
- room spacing;
- wall language;
- floor lanes;
- room entrances;
- integrated room-name signage;
- inactive-room concealment;
- activation lighting;
- extraction platform;
- transitions between chambers;
- environmental storytelling;
- anomaly effects.

Requirements:

- room progression must remain obvious;
- inactive rooms must not leak clues;
- future-room signs and clue panels must remain hidden until activation;
- the extraction platform must remain visually distinct;
- the environment must not permit puzzle bypasses;
- collision boundaries must remain reliable.

### Phase 6 — Individual puzzle room redesign

Each procedural room must use its own approved reference while remaining part
of the same visual system.

#### Signal Chamber

Reference:

- `docs/images/rooms/room_signal_chamber.png`

Improve:

- signal emitters;
- sequence presentation;
- console design;
- hidden clue surfaces;
- interaction feedback;
- success and failure states.

Preserve the existing sequence logic and difficulty scaling.

#### Invisible Floor

Reference:

- `docs/images/rooms/room_invisible_floor.png`

Improve:

- safe-tile language;
- containment walls;
- mandatory entrance;
- visual depth;
- hazard floor;
- clue visibility;
- row and turn readability.

Ensure the room cannot be bypassed from the sides.

Do not accidentally expose the safe route to players who should not see it.

#### Echo Sequence

Reference:

- `docs/images/rooms/room_echo_sequence.png`

Improve:

- colored panels;
- interaction pads;
- color sequencing;
- replay feedback;
- hidden clue presentation;
- success and failure effects.

Color values must remain readable under the new lighting.

Do not use colors so similar that they create accessibility or gameplay
problems.

#### Frequency Vault

Reference:

- `docs/images/rooms/room_frequency_vault.png`

Improve:

- quadrant segmentation;
- directional lanes;
- step-count visual language;
- floor markers;
- movement feedback;
- hidden clue presentation.

Preserve exact movement validation.

Decorative floor patterns must not be mistaken for functional indicators.

#### Power Grid

Reference:

- `docs/images/rooms/room_power_grid.png`

Improve:

- energy nodes;
- relays;
- switches;
- central puzzle board;
- circuitry;
- active and inactive states;
- optimal-solution readability;
- clue presentation.

Preserve the guaranteed solution and current validation logic.

### Phase 7 — HUD and menu redesign

Use `hud_ui.png`.

Refactor the UI visually without altering behavior.

Update:

- expedition HUD;
- phase indicator;
- timer;
- difficulty display;
- HOLD INFO panel;
- role information;
- Solo ALT VISION controls;
- mobile controls;
- Cosmetics panel;
- My Stats panel;
- result screen;
- shard indicators;
- queue-related UI where applicable.

Requirements:

- retain minimal HUD during expeditions;
- `H`, `L1`, and mobile HOLD INFO must continue working;
- ALT VISION must remain obvious and readable;
- support keyboard, gamepad, and touch;
- support common phone aspect ratios;
- use `UIScale`, `UIListLayout`, `UIPadding`,
  `UIAspectRatioConstraint`, or equivalent where appropriate;
- avoid absolute positioning that breaks on different resolutions;
- keep text readable;
- do not rely only on color for critical state;
- preserve localization-ready text handling if present;
- do not replace dynamic text with baked text images.

### Phase 8 — Player role visual language

Use `player_roles.png`.

Implement role distinction in a way compatible with user avatars.

Possible approaches include:

- role-colored accessory;
- lightweight visor effect;
- shoulder device;
- local highlight;
- role icon;
- overhead indicator;
- subtle particle or aura;
- HUD treatment.

Requirements:

- do not obstruct avatar visibility;
- do not create unfair information leakage;
- clue-only visuals must remain local to the authorized client;
- do not replicate hidden-role information globally unless intended;
- avoid military or heavy-armored styling;
- ensure role visuals work with different avatar sizes.

### Phase 9 — Solo drone redesign

Use `cosmetic_drone.png`.

Update the current drone model and effects while preserving:

- following behavior;
- Solo-only use;
- no gameplay advantage;
- server-authoritative restrictions;
- cosmetic customization support.

Requirements:

- readable silhouette;
- low instance count;
- lightweight particles;
- safe collision behavior;
- no camera obstruction;
- stable movement;
- no excessive network ownership issues;
- easy support for future cosmetic variants.

### Phase 10 — Reusable assets and instance construction

Prefer reusable builder functions for repeated visual structures, for example:

- wall panels;
- floor modules;
- sci-fi lights;
- consoles;
- signage;
- anomaly emitters;
- door frames;
- room headers;
- interaction pedestals;
- energy nodes.

Do not copy large blocks of nearly identical instance creation code.

Avoid a monolithic builder file.

Split visual construction into focused modules only where this improves
maintainability.

---

## Roblox implementation constraints

Use Roblox-native components whenever practical:

- `Part`;
- `MeshPart`;
- `Model`;
- `Attachment`;
- `Beam`;
- `Trail`;
- `ParticleEmitter`;
- `SurfaceGui`;
- `BillboardGui`;
- standard Roblox materials;
- `MaterialVariant`, where already supported by the project;
- `SurfaceAppearance`, only for appropriate MeshParts.

Do not assume that the concept images can be directly converted into usable
3D assets.

Do not create placeholder external asset IDs.

If a required custom mesh, texture, or decal does not exist:

1. implement the best Roblox-native approximation;
2. add a clearly documented asset requirement;
3. leave a safe configuration placeholder;
4. do not invent production asset IDs.

---

## Performance requirements

The redesign must remain suitable for mobile devices.

Avoid:

- excessive dynamic lights;
- hundreds of transparent overlapping parts;
- unnecessary unions;
- extremely high instance counts;
- dense particle systems;
- constantly running render-step effects;
- expensive per-frame searches;
- decorative objects with unnecessary collision;
- excessive shadow-casting lights;
- high-poly imported meshes without LOD consideration.

Apply where appropriate:

- `CanCollide = false` for decorative parts;
- `CanTouch = false`;
- `CanQuery = false`;
- anchored decorative geometry;
- reused assets;
- tagged or grouped instances;
- pooled effects;
- bounded particle lifetimes;
- client-only cosmetic effects when safe;
- server-authoritative gameplay state.

Do not trade gameplay readability for visual complexity.

---

## Security and networking requirements

The visual overhaul must not weaken the current server-authoritative design.

Do not move puzzle validation to the client.

Do not expose hidden clues to unauthorized clients.

Do not create new remotes unless necessary.

Any new remote must:

- have a clear contract;
- be validated server-side;
- be rate-limited consistently with the existing architecture;
- avoid trusting client-supplied gameplay state.

Keep ALT VISION timing and console lock validation server-authoritative.

---

## QA and compatibility requirements

Preserve compatibility with:

- `QAEnabled`;
- `QASeed`;
- `QAPreset`;
- `QADifficulty`;
- `QARole`;
- `QAPlayerCount`;
- `QAStartRoom`.

The graphical redesign must not obstruct the QA panel or alter deterministic
puzzle generation.

Test at minimum:

- Solo;
- 2-player group;
- 6-player group;
- Easy, Normal, and Hard;
- each forced puzzle preset;
- direct start at rooms 1, 2, and 3;
- keyboard;
- mobile layout;
- gamepad layout;
- ALT VISION;
- successful expedition;
- failed expedition;
- lobby interactions;
- Cosmetics;
- My Stats;
- Daily Reactor;
- Reality Mixer;
- Field Briefing;
- Anomaly Pad.

---

## Validation

After implementation, run the repository's quality workflow.

At minimum:

```powershell
rokit install
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\quality.ps1
rojo build tests.project.json --output tests.rbxlx
```

Also run any additional lint, formatting, test, or build commands discovered in
the repository.

Do not report the task as complete if formatting, linting, build, or tests fail.

---

## Suggested commit structure

Use separate commits so that each area can be reviewed or reverted independently:

1. `feat(visuals): introduce shared visual system and lighting`
2. `feat(lobby): rebuild lobby from approved visual reference`
3. `feat(expedition): redesign laboratory and extraction path`
4. `feat(rooms): redesign all five procedural puzzle rooms`
5. `feat(ui): overhaul HUD, menus, and responsive layouts`
6. `feat(roles): add role visual language and redesign solo drone`
7. `perf(visuals): optimize assets, effects, collisions, and QA compatibility`
8. `docs(visuals): document deviations, assets, and manual publishing steps`

Do not combine the entire overhaul into one unreviewable commit.

---

## Deliverables

Provide:

1. the initial art-to-implementation mapping;
2. a list of modified files;
3. a list of newly created files;
4. a summary of the visual system introduced;
5. a section for each redesigned area:
   - lobby;
   - expedition laboratory;
   - five puzzle rooms;
   - HUD/UI;
   - roles;
   - drone;
6. all deviations from the images and the technical reason;
7. missing external asset requirements;
8. performance considerations;
9. test results;
10. remaining manual Roblox Studio or Creator Dashboard steps.

---

## Acceptance criteria

The task is complete only when:

- all reference images have been reviewed;
- the game has one coherent visual language;
- lobby and expedition lab visibly reflect the approved concepts;
- every puzzle room has a distinct but consistent presentation;
- the HUD reflects the approved UI direction;
- roles are visually understandable;
- the Solo drone reflects its concept;
- existing game behavior remains intact;
- hidden clues remain correctly scoped;
- mobile readability and performance are preserved;
- QA mode remains functional;
- all quality checks pass;
- no fake asset IDs are introduced;
- implementation is modular and maintainable.

Begin by inspecting the repository and producing the art-to-implementation map.

Do not modify files until that audit is complete.
