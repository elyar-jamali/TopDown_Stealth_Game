# TopDown Stealth Game

A modular top-down stealth game developed with Godot 4.

## About

This project is an experimental stealth game built from scratch using Godot Engine.

The goal is to create a small but expandable stealth experience focused on reusable gameplay systems, interactive environments, NPC behavior, and clean project architecture.

This is a personal project developed in my spare time to explore game architecture, navigation, interaction systems, UI design, localization, and reusable game-development workflows.

## Engine

- Godot 4.x
- GDScript

## Current Features

### Player Movement and Interaction

- Top-down player movement
- Click-to-move navigation using `NavigationAgent3D`
- Improved movement recovery and detour handling
- Movement state system with idle, walk, run, crouch idle, and crouch walk states
- Crouch / stand switching with matching animations and movement behavior
- Walk / run movement with automatic animation switching
- Ground-speed synchronized locomotion animations to reduce foot sliding
- Shared animation controller with male / female animation sets, playback-speed control, and smooth blending
- Reusable interaction system
- Reusable door scenes with open, closed, and locked states
- Navigation-aware doors with detour handling
- Hover highlighting and contextual cursor states
- World-anchored hover labels for NPCs and doors
- Custom cursor system

### Pistol Combat and Procedural Aiming

- Mouse-directed pistol aiming with an aim trajectory preview and in-range / obstructed feedback
- Visual indicators for pistol firing range and shot sound radius
- Hover-based NPC target snapping with bullet collision checks from the weapon muzzle
- Standing and crouched pistol aiming and shooting, with male and female animation variants managed by `CharacterAnimationController`
- Limited ammunition, configurable starting ammo, and a live remaining-ammo HUD counter (no magazine reload mechanic)
- Fire-rate limiting synchronized with the procedural recoil duration
- Directional lethal NPC bullet impacts using the existing ragdoll system
- Procedural forearm recoil using `SkeletonModifier3D`, without interrupting the base aiming animation
- Procedural upper-body pitch adjustments for aiming toward elevated or nearby targets
- **Work in progress:** Dust and blood impact particle scenes are prototyped but their gameplay spawning is currently disabled pending visual improvements

### Stealth Takedowns and Ragdoll Physics

- Non-lethal knockout punches with directional, physics-based NPC falls
- Lethal garrote takedowns with synchronized attacker and victim animations
- Transition from the victim's kneeling garrote animation into a physics-driven fall
- NPC ragdolls implemented with `PhysicalBoneSimulator3D` and `PhysicalBone3D`
- Configured knee and elbow joint limits to reduce unnatural bending
- Physical collisions with the environment during ragdoll falls
- Automatic settling and pose freezing after a fall
- Unconscious NPC recovery with separate face-up and face-down wake-up animations
- Smooth transitions from the frozen ragdoll pose into wake-up animations and back to idle

### Guard and NPC Systems

- Guard vision system with obstacle occlusion
- Visual guard field-of-view overlay
- Standing / crouching visibility classification
- Character mesh rendering-layer fixes to prevent self-occlusion artifacts in guard vision overlays
- Shared NPC scene and script for patrol, interaction, consciousness, death, and ragdoll behavior
- Navigation-based NPC patrol system
- Loop, Ping-Pong, and Once patrol modes
- Configurable patrol start point, movement speed, wait time, and turning speed
- Navigation avoidance while patrolling
- Automatic idle / walk animation handling during patrol
- Shared patrol routes that can be assigned independently to NPCs
- Custom editor Waypoint Painter for creating patrol routes

### Character Appearance System

- Four selectable appearances for both player and NPC characters:
  - **Male Suit**
  - **Male Worker**
  - **Female Casual**
  - **Female Elegant**
- Runtime visual selection using reusable male and female character visual scenes
- Shared skeleton and animation workflows across compatible appearance variants
- Custom Godot editor plugin that previews the selected appearance in the 3D editor, including characters placed in levels
- Appearance changes integrated with animation playback and NPC ragdoll behavior
- Reorganized character assets with appearance-specific textures and a shared `common_textures` folder
- Optimized texture formats and resolutions while retaining PNG where transparency or image quality requires it
- Removed obsolete FBX source folders after verifying that character visuals still load following a fresh import-cache rebuild

### Character Animation System

- Reusable `CharacterAnimationController` shared by the player and NPCs
- Centralized action-to-animation mapping for male and female characters
- Automatic discovery of each character's `AnimationPlayer` within instanced visual scenes
- Configurable animation blending, action playback speeds, and reference movement speeds
- Blended idle / walk / run transitions and crouched locomotion
- Different wake-up animations chosen from the fallen NPC's orientation
- Female punch action supported using a temporary animation adapted from the male version; further animation polish is planned
- Standing and crouched pistol aiming animations selected through the shared animation controller

### Patrol Route Workflow

Patrol routes can be created directly in the Godot 3D editor using the **Waypoint Paint** tool.

- Enable `Waypoint Paint` from the 3D editor toolbar.
- Left-click a valid navigable surface to add patrol points.
- Drag an existing point to reposition it.
- Right-click a point to delete it.
- Use `Ctrl+Z` / Redo for editor undo and redo.
- Press `Esc` to leave waypoint painting mode.
- Waypoint numbers indicate the patrol order.

After creating a route:

1. Rename `WaypointDraft` to a route name such as `Guard01Route`.
2. Move it under the level's `PatrolRoutes` node.
3. Attach `PatrolRoute.gd` to `Guard01Route`.
4. Disable its visibility if the editor markers are no longer needed.
5. Assign the route to the NPC's `Patrol Route` property.
6. Select the desired patrol mode and patrol settings from the NPC Inspector.

Example scene structure:

```text
Level
├── PatrolRoutes
│   ├── Guard01Route
│   │   ├── Point_001
│   │   ├── Point_002
│   │   └── Point_003
│   └── Guard02Route
├── Guard01
└── Guard02
```

Patrol routes only store ordered waypoint positions. Patrol behavior such as Loop, Ping-Pong, Once, movement speed, and wait time is configured independently on each NPC.

### Tactical Map

- Resizable tactical map
- Independent map camera
- Click-to-recenter map navigation
- Map zoom controls
- Player and NPC map markers
- Configurable marker colors
- Visibility filtering for map-only rendering
- Map panel size persistence during gameplay
- Localized map title and HUD integration

### HUD and UI

- Gameplay HUD with player portrait, health display, and horizontal health bar
- Reusable HUD action-slot component
- Action slots for crouch / stand, knockout, lethal takedown, pistol, scoped rifle, and healing
- Live pistol ammunition count displayed in the pistol action slot
- Right-side HUD foundation for map and dialogue / log access
- Dynamic shortcut labels read directly from Godot `InputMap`
- Custom HUD icon set for crouch / stand, knockout, lethal takedown, pistol, scoped rifle, healing, map, and log
- Shared portrait / map shader with configurable mirrored curved corner and border
- Main menu and in-game pause menu
- Reusable custom dialog system used by menus and confirmations
- Responsive UI layouts built with Godot containers
- Multiple UI themes
- Theme selection and persistence
- Shared settings panel

### Input and Localization

- Centralized `InputMap`-based controls instead of hard-coded gameplay keys
- User-configurable keyboard and mouse key mapping
- Key-binding conflict detection and replacement
- Reset-to-default controls
- Persistent custom key bindings
- Keyboard and mouse shortcuts routed to the same gameplay / HUD actions as mouse clicks
- Camera movement, rotation, and zoom mapped through `InputMap`
- Dynamic localization system
- JSON-based language files
- Runtime language switching and persistence
- Dialogue system with timed and manual closing

## Default Controls

| Input | Action |
| --- | --- |
| Left Mouse Button | Move or interact; fire one pistol shot while aiming |
| Right Mouse Button | Cancel the current action / leave pistol aiming |
| Middle Mouse Button | Toggle a guard's vision field |
| Space | Crouch / stand, including while aiming |
| 1 | Knockout action slot |
| 2 | Lethal takedown action slot |
| 3 | Pistol action slot / enter pistol aiming |
| 4 | Scoped rifle action slot |
| 5 | Heal action slot |
| M | Map |
| L | Dialogue / log |
| Alt + Mouse Movement | Rotate and tilt the camera |
| Mouse Wheel | Zoom in / out |
| Tab | Highlight interactive objects |
| W / A / S / D | Move the camera |
| Q / E | Rotate the camera |

> **Development note:** Controls are defined through Godot `InputMap` and can be changed through the in-game key-mapping interface. HUD shortcut labels update dynamically from the current bindings.

## Character Workflow

The character assets were prepared using **MakeHuman** and **Adobe Mixamo** as part of the modeling, rigging, and animation workflow.

The game uses reusable male and female visual scenes and separate appearance scenes containing meshes and skin bindings. The selected appearance is applied to player and NPC characters at runtime and can also be previewed through a custom editor plugin.

Character animation data is stored as Godot resources and accessed through the visual scenes. The original FBX source files are no longer required for the current character appearance workflow.

Player and NPC animation playback is managed through a reusable `CharacterAnimationController`. Each character selects its male or female animation set, while the controller handles action lookup, playback speed, and blended transitions.

NPC ragdoll physics is handled separately by `RagdollDriver`, allowing transitions from animated takedowns or pistol takedowns to physical falls and from a frozen ragdoll pose back to wake-up animations. Character visuals and their physics rigs remain scene-specific.

Pistol recoil and upper-body aim pitch are applied procedurally through a custom `SkeletonModifier3D` script, layered over the standing or crouched aiming pose. The recoil duration also controls the minimum interval between pistol shots.

Character textures are stored in appearance-specific folders, with reusable textures kept in `common_textures`. Texture resolution and format are chosen according to the needs of the game, including retaining transparency where necessary.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for asset and licensing notes.

## Planned Features

- Additional takedown reactions and interactions
- Further NPC recovery and ragdoll polish
- Save / Load system
- Pickups and additional weapons
- Polish pistol impact VFX (dust puffs and blood effects; particle prototypes are currently disabled)
- Gunshot audio and guard reactions to firearm noise
- More advanced NPC AI and guard state machine
- Additional NPC variants
- Multiple levels
- Additional character and NPC animations, including further refinement of the female punch animation
- Audio system
- Inventory system (possible future feature)
- Character customization, including adjustable hair and clothing colors using reusable materials and textures

## Project Status

**Early development / prototype stage**

The project is under active development. Systems are being built incrementally, tested independently, and refactored as the project grows. Knockout and garrote takedowns, physics-based NPC falls, recovery animations, the shared animation controller, and four selectable character appearances are currently implemented. Pistol combat is now playable, including standing and crouched aiming, limited ammunition, NPC bullet takedowns, procedural recoil, and upper-body aim adjustments. Bullet impact visual effects remain experimental and are disabled while their appearance is being reworked. Character assets have also been reorganized and validated after removal of obsolete FBX dependencies.

Development updates and discussion: [Godot Forum](https://forum.godotengine.org/t/commandos-games-style-top-down-stealth-prototype-in-godot-4-navigation-guard-vision-interactions-and-camera-system-full-source-code-on-github/144726).

## License

The original source code in this repository is available free of charge for personal, educational, academic, research, and other non-commercial use.

Attribution is required for public use or redistribution.

If this code is modified, forked, adapted, or extended and the resulting code is published or redistributed, the modified version must clearly reference this original repository, retain the applicable copyright/license notice, and state that it is derived from this project.

Commercial use is not permitted without prior written permission. Commercial projects require a separate license from the copyright holder and may be subject to a licensing fee, revenue-sharing agreement, or other agreed terms.

See the LICENSE file for the complete terms.

Third-party models, animations, textures, fonts, libraries, and other assets are not covered by this license and remain subject to their respective terms. See `THIRD_PARTY_NOTICES.md` where applicable.
