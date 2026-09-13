# Changelog

## v0.9.0-alpha

- MacroUI button connection lifecycle and MainUI static drag cleanup
- Dropdown silent state synchronization and direct macro selector callbacks
- Player completion cleanup, MacroStatus normalization, and Join Once validation

## v0.8.0-alpha

- AutomationController lifecycle and conditional defaults
- UI connection and subscription cleanup improvements
- Player/Recorder mutual exclusion and paused recording finalization
- GameDetector and speed-state consistency regression coverage

## v0.6.0-alpha

- Automation UI rebuilt with State bindings and exclusive selectors
- Scrollable Automation and Macro interfaces, restore button, and UI cleanup
- Pytest discovery fixed with a static validation suite

## v1.1.0

### Added
- Game Integration layer with GameAdapter, ActionRegistry, GameState, and Integration modules
- Abstract macro actions for SELECT_UNIT, PLACE_UNIT, UPGRADE_UNIT, SELL_UNIT, SKIP_WAVE, and PLAY_AGAIN
- Pending integration guard that keeps the game bridge isolated and explicit
- Game adapter hook for future concrete integration without modifying UI or macro managers

### Changed
- Recorder now records abstract action payloads with type, timestamp, delay, data, and id
- Player now executes recorded actions through GameAdapter instead of directly mixing game logic into playback
- Readme updated with the new execution flow and architecture

## v1.0.0

### Added
- Initial Garden Hub UI structure
- Core architecture for config, state, logger, and game detection
- Automation and macro tabs
- Macro recording, playback, validation, storage, import, and export
- Documentation for usage and architecture

### Changed
- Centralized theme and state management
- Modern black/white/blue UI styling

### Fixed
- Loader duplication guard and game validation flow
- State updates and macro validation error handling
