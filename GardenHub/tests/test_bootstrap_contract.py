import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "src"


def test_main_bootstrap_contract():
    text = (SRC / "main.lua").read_text(encoding="utf-8")
    order = [
        "initializeCore()",
        "GardenHub.GameDetector:IsValidGame()",
        "initializeStorage()",
        "initializeGame()",
        "initializeMacros()",
        "initializeUI()",
        "connectControllers()",
    ]
    for token in order:
        assert token in text, f"Missing bootstrap token: {token}"


def test_module_loader_is_single_entrypoint():
    files = list(SRC.rglob("*.lua"))
    banned = []
    for path in files:
        if path.name in {"ModuleLoader.lua", "main.lua", "AutomationController.lua"}:
            continue
        text = path.read_text(encoding="utf-8")
        if 'require("GardenHub.src.' in text or 'require("src.' in text:
            banned.append(str(path.relative_to(ROOT)))
    assert not banned, f"Found forbidden direct root requires: {banned}"


def test_real_controller_exists():
    controller = SRC / "controllers" / "AutomationController.lua"
    assert controller.exists(), "Automation controller missing from project tree."
    content = controller.read_text(encoding="utf-8")
    assert "function AutomationController:Bind()" in content, "Controller bind method is missing."


