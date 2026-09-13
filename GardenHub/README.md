# Garden Hub

Garden Hub is a modular automation and macro framework for Garden Tower Defense. The project is organized around a clear separation of concerns so the UI, state, storage, and macro logic can evolve independently.

## Features

- Macro UI implemented; Automation UI implemented
- GHM1 supported; MemoryStorage fallback is used when no persistent provider exists
- ConcreteBridge pending for real game integration
- Persistent provider pending; runtime validation pending in an authorized Roblox environment

- Safe loader with duplicate protection and GameId validation
- Centralized config and state management
- Modern black, white, and blue UI theme
- Automation panel with farm mode toggles and tick speed selectors
- Macro recording, playback, management, duplication, deletion, and validation
- Share code generation for macro export
- Import validation and duplicate handling
- Event logging and notification-ready pipeline
- Extensible architecture for future features

## Architecture

Garden Hub is split into the following areas:

- Core: configuration, state, logging, and game detection
- UI: theme and panels for automation and macro management
- Macros: recorder, player, manager, serializer, importer, and exporter
- Storage: macro and settings persistence
- Game Integration: abstract action registry, bridge-ready adapter, and game state adapter layer

The execution flow is:

```text
UI
 ↓
Macro Manager
 ↓
Recorder / Player
 ↓
GameAdapter
 ↓
Game Integration
```

This keeps the UI and macro engine independent from the concrete game integration layer, which is intentionally isolated and ready for future bindings.

## Folder Structure

```text
GardenHub/
├── loader.lua
├── src/
│   ├── main.lua
│   ├── core/
│   │   ├── Config.lua
│   │   ├── State.lua
│   │   ├── Logger.lua
│   │   └── GameDetector.lua
│   ├── ui/
│   │   ├── Theme.lua
│   │   ├── MainUI.lua
│   │   ├── Automation.lua
│   │   └── MacroUI.lua
│   ├── macros/
│   │   ├── MacroManager.lua
│   │   ├── Recorder.lua
│   │   ├── Player.lua
│   │   ├── Serializer.lua
│   │   ├── Importer.lua
│   │   └── Exporter.lua
│   ├── game/
│   │   ├── GameAdapter.lua
│   │   ├── ActionRegistry.lua
│   │   ├── GameState.lua
│   │   └── Integration.lua
│   └── storage/
│       ├── MacroStorage.lua
│       └── SettingsStorage.lua
├── README.md
└── CHANGELOG.md
```

## Macro Format

Macros are stored in a structured format with a clear version and metadata block. The base format is:

```lua
{
    format = "GHM",
    version = 1,
    name = "Volcano Hell",
    game = {
        name = "Garden Tower Defense",
        gameId = 7703614594,
    },
    createdAt = 0,
    updatedAt = 0,
    settings = {
        replayMode = "By Cash",
    },
    actions = {}
}
```

## Import and Export

- Exported macros use a portable share code prefixed with `GHM1:` through `GHM3:`.
- Import checks format, version, GameId, and macro structure before saving.
- Duplicate names require an explicit decision: rename, replace, or cancel.

## Configuration

Settings are centralized through the config module and storage layer, which keeps UI, macro behavior, and persistence rules separated from the runtime logic.

## Changelog

See CHANGELOG.md for release notes.
