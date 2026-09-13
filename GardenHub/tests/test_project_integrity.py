import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "src"

EXPECTED = {
    "src/core/Config.lua",
    "src/core/State.lua",
    "src/core/Logger.lua",
    "src/core/GameDetector.lua",
    "src/core/ModuleLoader.lua",
    "src/game/ActionRegistry.lua",
    "src/game/GameAdapter.lua",
    "src/game/GameState.lua",
    "src/game/Integration.lua",
    "src/macros/Recorder.lua",
    "src/macros/Player.lua",
    "src/macros/MacroManager.lua",
    "src/macros/Serializer.lua",
    "src/macros/Importer.lua",
    "src/macros/Exporter.lua",
    "src/storage/MacroStorage.lua",
    "src/storage/SettingsStorage.lua",
    "src/ui/Theme.lua",
    "src/ui/MainUI.lua",
    "src/ui/Automation.lua",
    "src/ui/components/Dropdown.lua",
    "src/ui/MacroUI.lua",
    "src/controllers/AutomationController.lua",
    "src/main.lua",
    "loader.lua",
}


def test_all_modules_exist():
    missing = sorted(str(path.relative_to(ROOT)) for path in sorted({ROOT / rel for rel in EXPECTED}) if not path.exists())
    assert not missing, f"Missing expected files: {missing}"


def test_no_broken_internal_requires():
    bad_pattern = re.compile(r'require\("GardenHub\.')
    violations = []
    for path in sorted(SRC.rglob("*.lua")):
        text = path.read_text(encoding="utf-8")
        matches = bad_pattern.findall(text)
        if matches:
            violations.append((str(path.relative_to(ROOT)), matches[:3]))
    assert not violations, f"Broken internal require patterns found: {violations}"


def test_required_contracts():
    main_text = (SRC / "main.lua").read_text(encoding="utf-8")
    assert "initializeCore()" in main_text and "initializeStorage()" in main_text and "initializeGame()" in main_text and "initializeMacros()" in main_text and "initializeUI()" in main_text, "Bootstrap order is incomplete."

    game_adapter = (SRC / "game" / "GameAdapter.lua").read_text(encoding="utf-8")
    assert "definition.handler(action)" in game_adapter, "GameAdapter still uses the old definition handler flow."

    player = (SRC / "macros" / "Player.lua").read_text(encoding="utf-8")
    assert 'self.Status == "Paused"' in player and "WorkerActive" in player, "Player pause/resume lifecycle is incomplete."

    serializer = (SRC / "macros" / "Serializer.lua").read_text(encoding="utf-8")
    assert "JSONEncode" in serializer and "JSONDecode" in serializer, "Serializer contract is incomplete."


def test_automation_required_controls():
    text = (SRC / "ui" / "Automation.lua").read_text(encoding="utf-8")
    for label in ("Auto Farm Seeds V5", "Auto Farm Seeds V4", "Auto Farm Seeds V2", "Auto Farm Win", "Auto Equip Units", "Auto Skip Wave", "Auto Play Again", "Turn Off Global Play", "Select Map", "Select Difficulty", "Auto Join Map", "Auto Select Difficulty", "Join Once"):
        assert label in text


def test_removed_old_automation_options():
    text = (SRC / "ui" / "Automation.lua").read_text(encoding="utf-8")
    for label in ("Collect rewards", "Skip empty waves", "Auto revive", "Volcano map", "Night difficulty", "Use best route"):
        assert label not in text


def test_scrollable_interfaces():
    assert "ScrollingFrame" in (SRC / "ui" / "Automation.lua").read_text(encoding="utf-8")
    assert "ScrollingFrame" in (SRC / "ui" / "MacroUI.lua").read_text(encoding="utf-8")


def test_restore_button_exists():
    text = (SRC / "ui" / "MainUI.lua").read_text(encoding="utf-8")
    assert "RestoreButton" in text
    assert "frame.Visible = false" in text and "restoreButton.Visible = true" in text


def test_serializer_does_not_treat_game_as_table():
    text = (SRC / "macros" / "Serializer.lua").read_text(encoding="utf-8")
    assert 'type(game) ~= "table"' not in text
    assert 'type(game) == "table"' not in text


def test_module_loader_does_not_require_string_candidates():
    text = (SRC / "core" / "ModuleLoader.lua").read_text(encoding="utf-8")
    assert "require(candidate)" not in text
    assert "findModuleScript" in text and "require(moduleScript)" in text


def test_macro_manager_success_paths():
    text = (SRC / "macros" / "MacroManager.lua").read_text(encoding="utf-8")
    assert 'return saved and macro or false, "Failed to create macro."' not in text
    assert 'return ok and clone or false, "Failed to duplicate macro."' not in text
    assert "if not saved then" in text and "if not result then" in text


def test_ui_cleanup_contracts():
    for name in ("MainUI.lua", "MacroUI.lua", "Automation.lua"):
        text = (SRC / "ui" / name).read_text(encoding="utf-8")
        assert "Unsubscribe" in text or "Disconnect" in text


def test_automation_live_status_and_player_repeat_contracts():
    automation = (SRC / "ui" / "Automation.lua").read_text(encoding="utf-8")
    player = (SRC / "macros" / "Player.lua").read_text(encoding="utf-8")
    macro_ui = (SRC / "ui" / "MacroUI.lua").read_text(encoding="utf-8")
    assert 'subscribe("CurrentMap"' in automation and 'subscribe("CurrentDifficulty"' in automation
    assert "function Player:SetRepeat" in player and "Player:SetRepeat" in macro_ui


def test_no_game_table_assumption_anywhere():
    for path in SRC.rglob("*.lua"):
        text = path.read_text(encoding="utf-8")
        assert 'type(game) ~= "table"' not in text and 'type(game) == "table"' not in text


def test_automation_controller_preserves_existing_state():
    text = (SRC / "controllers" / "AutomationController.lua").read_text(encoding="utf-8")
    assert "local function setDefault" in text and 'State:Get(key)==nil' in text


def test_automation_controller_subscribes_and_unbinds():
    text = (SRC / "controllers" / "AutomationController.lua").read_text(encoding="utf-8")
    assert "State:Subscribe" in text and "State:Unsubscribe" in text and "function AutomationController:Unbind" in text


def test_mainui_tracks_and_cleans_subscriptions():
    text = (SRC / "ui" / "MainUI.lua").read_text(encoding="utf-8")
    assert "function MainUI:Track" in text and "Disconnect" in text and "Logger:Unsubscribe" in text and "State:Unsubscribe" in text


def test_recorder_pause_stop_and_speed_consistency():
    recorder = (SRC / "macros" / "Recorder.lua").read_text(encoding="utf-8")
    controller = (SRC / "controllers" / "AutomationController.lua").read_text(encoding="utf-8")
    assert "self.TotalPausedTime = self.TotalPausedTime +" in recorder and "actions = deepClone(self.Actions)" in recorder
    assert 'State:Set("Speed", "x"' in controller


def test_macroui_tracks_button_connections():
    text = (SRC / "ui" / "MacroUI.lua").read_text(encoding="utf-8")
    assert "module.Connections" in text and "local function connect" in text and "connection:Disconnect()" in text
    assert ".MouseButton1Click:Connect" not in text


def test_mainui_drag_is_fully_tracked():
    text = (SRC / "ui" / "MainUI.lua").read_text(encoding="utf-8")
    assert "titleBar.InputChanged:Connect" in text and "dragConnection" not in text


def test_dropdown_supports_silent_programmatic_selection():
    text = (SRC / "ui" / "components" / "Dropdown.lua").read_text(encoding="utf-8")
    assert "function Dropdown:SetSelected(value, silent)" in text and "silent ~= true" in text


def test_macro_selector_uses_selected_value_directly():
    text = (SRC / "ui" / "MacroUI.lua").read_text(encoding="utf-8")
    assert "OnChanged(function(selectedName)" in text
    assert "currentIndex = currentIndex + 1" not in text


def test_player_completion_and_join_once_validation():
    player = (SRC / "macros" / "Player.lua").read_text(encoding="utf-8")
    controller = (SRC / "controllers" / "AutomationController.lua").read_text(encoding="utf-8")
    complete = player.split("function Player:Load", 1)[0]
    assert "task.cancel(self.TaskHandle)" not in complete
    assert "Select a map before Join Once." in controller and "Select a difficulty before Join Once." in controller


def test_automation_tracks_control_connections():
    text = (SRC / "ui" / "Automation.lua").read_text(encoding="utf-8")
    for token in ("module.Controls", "module.Connections", "module.Dropdowns", "function o:Destroy", "once.MouseButton1Click", "head.MouseButton1Click"):
        assert token in text


def test_player_blocks_recording_paused_status():
    text = (SRC / "macros" / "Player.lua").read_text(encoding="utf-8")
    assert "RecordingPaused" in text
    assert "RecordPaused" not in text


def test_macro_buttons_are_connected_or_removed():
    text = (SRC / "ui" / "MacroUI.lua").read_text(encoding="utf-8")
    assert "importCodeButton" not in text
    for variable in ("createButton", "saveButton", "loadButton", "deleteButton", "duplicateButton", "importButton"):
        assert f"connect({variable}.MouseButton1Click" in text


def test_macro_rows_fit_and_recorder_uses_current_replay_mode():
    macro_ui = (SRC / "ui" / "MacroUI.lua").read_text(encoding="utf-8")
    recorder = (SRC / "macros" / "Recorder.lua").read_text(encoding="utf-8")
    assert '"Create", 0.22' not in macro_ui
    assert 'State:Get("ReplayMode", "Once")' in recorder
    assert "By Cash" not in recorder


def test_player_completion_and_recorder_session_cleanup():
    player = (SRC / "macros" / "Player.lua").read_text(encoding="utf-8")
    recorder = (SRC / "macros" / "Recorder.lua").read_text(encoding="utf-8")
    complete = player.split("function Player:Load", 1)[0]
    assert "self.IsPaused = false" in complete and "self.PauseStartedAt = nil" in complete
    assert "self.CurrentMacroName = nil" in recorder and "self.TotalPausedTime = 0" in recorder


def test_automation_does_not_use_global_active_module():
    text = (SRC / "ui" / "Automation.lua").read_text(encoding="utf-8")
    assert "activeModule" not in text


