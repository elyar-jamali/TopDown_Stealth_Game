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

- Top-down player movement
- Click-to-move navigation using `NavigationAgent3D`
- Walk / run movement with automatic animation switching
- Reusable interaction system
- Reusable door scenes with open, closed, and locked states
- Navigation-aware doors
- Basic NPC structure and interaction
- Hover highlighting and contextual cursor states
- Custom cursor system
- Main menu and in-game pause menu
- Responsive UI layouts built with Godot containers
- Multiple UI themes
- Theme selection and persistence
- Settings panel
- Dynamic localization system
- JSON-based language files
- Runtime language switching and persistence
- Confirmation dialogs
- Dialogue system with timed and manual closing

## Character Workflow

The current player character was created with **MakeHuman** and rigged/animated using **Adobe Mixamo**.

The animation tracks used by the game are stored inside the Godot player visual scene. The original animation source files are not required at runtime.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for asset and licensing notes.

## Planned Features

- Save / Load system
- Key remapping
- More advanced NPC AI
- Multiple levels
- Additional character and NPC animations
- Inventory system (possible future feature)
- Character customization

## Project Status

**Early development / prototype stage**

The project is under active development. Systems are being built incrementally, tested independently, and refactored as the project grows.

## License

The original source code in this repository is available free of charge forpersonal, educational, academic, research, and other non-commercial use.

Attribution is required for public use or redistribution.

If this code is modified, forked, adapted, or extended and the resulting codeis published or redistributed, the modified version must clearly referencethis original repository, retain the applicable copyright/license notice,and state that it is derived from this project.

Commercial use is not permitted without prior written permission.Commercial projects require a separate license from the copyright holder andmay be subject to a licensing fee, revenue-sharing agreement, or other agreedterms.

See the LICENSE file for the complete terms.

Third-party models, animations, textures, fonts, libraries, and other assetsare not covered by this license and remain subject to their respective terms.See THIRD_PARTY_NOTICES.md where applicable.