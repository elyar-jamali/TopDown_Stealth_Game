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
- Reusable interaction system
- Reusable door scenes with open, closed, and locked states
- Navigation-aware doors with detour handling
- Hover highlighting and contextual cursor states
- Custom cursor system

### Guard and NPC Systems

- Guard vision system with obstacle occlusion
- Visual guard field-of-view overlay
- Standing / crouching visibility classification
- Basic NPC structure, interaction, and ground physics

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
- Settings panel

### Input and Localization

- Centralized `InputMap`-based controls instead of hard-coded gameplay keys
- Keyboard and mouse shortcuts routed to the same gameplay / HUD actions as mouse clicks
- Camera movement, rotation, and zoom mapped through `InputMap`
- Dynamic localization system
- JSON-based language files
- Runtime language switching and persistence
- Dialogue system with timed and manual closing

## Controls

| Input | Action |
| --- | --- |
| Left Mouse Button | Move the player or interact with objects |
| Right Mouse Button | Cancel the current action |
| Middle Mouse Button | Toggle a guard's vision field |
| Space | Crouch / stand |
| 1 | Knockout action slot |
| 2 | Lethal takedown action slot |
| 3 | Pistol action slot |
| 4 | Scoped rifle action slot |
| 5 | Heal action slot |
| M | Map |
| L | Dialogue / log |
| Alt + Mouse Movement | Rotate and tilt the camera |
| Mouse Wheel | Zoom in / out |
| Tab | Highlight interactive objects |
| W / A / S / D | Move the camera |
| Q / E | Rotate the camera |

> **Development note:** Controls are defined through Godot `InputMap`. The HUD reads the current shortcut bindings dynamically, providing the foundation for future user-configurable key remapping.

> **Development note:** Debug vision rays from guards to the player are currently left enabled for vision-system testing.

## Character Workflow

The current player character was created with **MakeHuman** and rigged/animated using **Adobe Mixamo**.

The animation tracks used by the game are stored inside the Godot player visual scene. The original animation source files are not required at runtime.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for asset and licensing notes.

## Planned Features

- Mini map and full map system
- Save / Load system
- User-configurable key remapping UI
- More advanced NPC AI and guard state machine
- Multiple levels
- Additional character and NPC animations
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
