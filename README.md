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
- Shared male / female animation data and reference movement speeds
- Reusable interaction system
- Reusable door scenes with open, closed, and locked states
- Navigation-aware doors with detour handling
- Hover highlighting and contextual cursor states
- World-anchored hover labels for NPCs and doors
- Custom cursor system

### Guard and NPC Systems

- Guard vision system with obstacle occlusion
- Visual guard field-of-view overlay
- Standing / crouching visibility classification
- Basic NPC structure, interaction, and ground physics
- Navigation-based NPC patrol system
- Loop, Ping-Pong, and Once patrol modes
- Configurable patrol start point, movement speed, wait time, and turning speed
- Navigation avoidance while patrolling
- Automatic idle / walk animation handling during patrol
- Shared patrol routes that can be assigned independently to NPCs
- Custom editor Waypoint Painter for creating patrol routes

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
| Left Mouse Button | Move the player or interact with objects |
| Right Mouse Button | Cancel the current action |
| Middle Mouse Button | Toggle a guard's vision field |
| Space | Crouch / stand |
| F1 | Knockout action slot |
| F2 | Lethal takedown action slot |
| F3 | Pistol action slot |
| F4 | Scoped rifle action slot |
| F5 | Heal action slot |
| M | Map |
| L | Dialogue / log |
| Alt + Mouse Movement | Rotate and tilt the camera |
| Mouse Wheel | Zoom in / out |
| Tab | Highlight interactive objects |
| W / A / S / D | Move the camera |
| Q / E | Rotate the camera |

> **Development note:** Controls are defined through Godot `InputMap` and can be changed through the in-game key-mapping interface. HUD shortcut labels update dynamically from the current bindings.

## Character Workflow

The current player character was created with **MakeHuman** and rigged/animated using **Adobe Mixamo**.

The animation tracks used by the game are stored inside the Godot character visual scenes. The original animation source files are not required at runtime.

Male and female locomotion animations use shared animation metadata so NPCs and the player can automatically select the correct animation set and synchronize animation playback with actual ground movement speed.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for asset and licensing notes.

## Planned Features

- Player knockout and lethal takedown mechanics
- NPC alive / knocked-out / dead states
- Save / Load system
- Pickups and weapons
- More advanced NPC AI and guard state machine
- Additional NPC variants
- Multiple levels
- Additional character and NPC animations
- Audio system
- Inventory system (possible future feature)
- Character customization

## Project Status

**Early development / prototype stage**

The project is under active development. Systems are being built incrementally, tested independently, and refactored as the project grows.

## License

The original source code in this repository is available free of charge for personal, educational, academic, research, and other non-commercial use.

Attribution is required for public use or redistribution.

If this code is modified, forked, adapted, or extended and the resulting code is published or redistributed, the modified version must clearly reference this original repository, retain the applicable copyright/license notice, and state that it is derived from this project.

Commercial use is not permitted without prior written permission. Commercial projects require a separate license from the copyright holder and may be subject to a licensing fee, revenue-sharing agreement, or other agreed terms.

See the LICENSE file for the complete terms.

Third-party models, animations, textures, fonts, libraries, and other assets are not covered by this license and remain subject to their respective terms. See `THIRD_PARTY_NOTICES.md` where applicable.
