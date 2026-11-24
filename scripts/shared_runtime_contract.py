"""Narrow source-contract exceptions for cooperative State QML modules.

This is dependency validation, not a QML sandbox or trusted-caller check.
Changing either exact module or importer roster is an explicit architecture
change.
"""
from collections import deque
from itertools import islice
from pathlib import Path
import os
import posixpath
import re
from scripts.qml_import_lexer import ImportLexError, tokens

MODULE = Path("shinigami.state/runtime")
MODULE_FILES = frozenset({"qmldir", "Runtime.qml", "Provider.qml", "HostShell.qml", "HostContract.qml"})
IMPORTERS = frozenset({
    "shinigami.ai/Service.qml",
    "shinigami.audio/BarWidget.qml",
    "shinigami.audio/Service.qml",
    "shinigami.bar/Bar.qml",
    "shinigami.battery/BarWidget.qml",
    "shinigami.bluetooth/Service.qml",
    "shinigami.display-manager/Service.qml",
    "shinigami.center/Service.qml",
    "shinigami.control-center/BarWidget.qml",
    "shinigami.control-center/PluginUpdateService.qml",
    "shinigami.cpu/BarWidget.qml",
    "shinigami.cpu/Service.qml",
    "shinigami.gpu/BarWidget.qml",
    "shinigami.media/BarWidget.qml",
    "shinigami.media/Service.qml",
    "shinigami.memory/BarWidget.qml",
    "shinigami.network/Service.qml",
    "shinigami.network/NetworkPanelBridge.qml",
    "shinigami.onedrive/Service.qml",
    "shinigami.power-profile/BarWidget.qml",
    "shinigami.power-state/Service.qml",
    "shinigami.quick-access/Service.qml",
    "shinigami.reactor/Service.qml",
    "shinigami.reactor/BoundedTextSource.qml",
    "shinigami.status/Service.qml",
    "shinigami.storage/BarWidget.qml",
    "shinigami.storage/Service.qml",
    "shinigami.telemetry/Service.qml",
    "shinigami.temperature/BarWidget.qml",
    "shinigami.update-center/Service.qml",
    "shinigami.workspaces/BarWidget.qml",
    "shinigami.workspaces/WorkspaceService.qml",
})

PRESENTATION_MODULE = Path("shinigami.state/lib/presentation")
PRESENTATION_MODULE_FILES = frozenset({
    "qmldir",
    "BarGlyph.qml",
    "BarInk.qml",
    "BarSymbols.js",
    "ControlCenterIconText.qml",
    "HostTokens.qml",
    "IconText.qml",
    "InkRow.qml",
    "PacmanWorkspaceMarker.qml",
    "PanelHeading.qml",
    "PillSurface.qml",
    "ShinigamiPanelToolTip.qml",
    "ShinigamiPillToolTip.qml",
})
PRESENTATION_IMPORTERS = frozenset({
    "shinigami.ai/AiUsagePanel.qml",
    "shinigami.ai/BarWidget.qml",
    "shinigami.audio/AudioPanel.qml",
    "shinigami.audio/BarWidget.qml",
    "shinigami.battery/BarWidget.qml",
    "shinigami.battery/BatteryPanel.qml",
    "shinigami.bluetooth/BarWidget.qml",
    "shinigami.bluetooth/BluetoothPanel.qml",
    "shinigami.display-manager/BarWidget.qml",
    "shinigami.display-manager/BrightnessPanel.qml",
    "shinigami.center/BarWidget.qml",
    "shinigami.center/CalendarPanel.qml",
    "shinigami.center/ClockWidget.qml",
    "shinigami.center/StatusIndicators.qml",
    "shinigami.center/SystemUpdateWidget.qml",
    "shinigami.center/WeatherPanel.qml",
    "shinigami.control-center/ActiveBarSettingsPage.qml",
    "shinigami.control-center/AppearanceWidgetTile.qml",
    "shinigami.control-center/BarWidget.qml",
    "shinigami.control-center/ConfigureLandingPage.qml",
    "shinigami.control-center/ControlCenterPanel.qml",
    "shinigami.control-center/ControlSearchPage.qml",
    "shinigami.control-center/ControlSettings.qml",
    "shinigami.control-center/PageHeaderHero.qml",
    "shinigami.control-center/PluginCatalogPage.qml",
    "shinigami.control-center/PluginProviderSummary.qml",
    "shinigami.control-center/PluginSectionHeader.qml",
    "shinigami.control-center/PredictiveSearchInput.qml",
    "shinigami.control-center/QuickControlPage.qml",
    "shinigami.control-center/SemanticPreviewImage.qml",
    "shinigami.control-center/WidgetAppearanceWorkbench.qml",
    "shinigami.control-center/WidgetModuleTile.qml",
    "shinigami.control-center/WorkspaceMarkerPreviewCard.qml",
    "shinigami.cpu/BarWidget.qml",
    "shinigami.gpu/BarWidget.qml",
    "shinigami.gpu/GpuPanel.qml",
    "shinigami.indicators/BarWidget.qml",
    "shinigami.media/BarWidget.qml",
    "shinigami.media/MediaPanel.qml",
    "shinigami.memory/BarWidget.qml",
    "shinigami.network/BarWidget.qml",
    "shinigami.network/NetworkPanel.qml",
    "shinigami.onedrive/BarWidget.qml",
    "shinigami.wallpaper-manager/BarWidget.qml",
    "shinigami.power-profile/BarWidget.qml",
    "shinigami.power-profile/PowerProfilePanel.qml",
    "shinigami.quick-access/BarWidget.qml",
    "shinigami.quick-access/CarouselPickerImage.qml",
    "shinigami.quick-access/HearthstonePickerView.qml",
    "shinigami.quick-access/PickerImage.qml",
    "shinigami.quick-access/PickerOverlay.qml",
    "shinigami.quick-access/Service.qml",
    "shinigami.status/BarWidget.qml",
    "shinigami.status/NotificationPanel.qml",
    "shinigami.status/NotificationStatusView.qml",
    "shinigami.status/TrayAppMenuPanel.qml",
    "shinigami.status/TrayDrawerPanel.qml",
    "shinigami.status/TrayStatusView.qml",
    "shinigami.storage/BarWidget.qml",
    "shinigami.temperature/BarWidget.qml",
    "shinigami.temperature/TemperaturePanel.qml",
    "shinigami.update-center/BarWidget.qml",
    "shinigami.update-center/PanelButton.qml",
    "shinigami.update-center/ThemesTab.qml",
    "shinigami.update-center/UpdateCenterPanel.qml",
    "shinigami.workspaces/BarWidget.qml",
    "shinigami.workspaces/WorkspacePanelContent.qml",
})


# Paths accept no escapes or URL encodings. Unsupported lexical ambiguity
# fails closed; this remains static dependency lint, not a QML sandbox.
def quoted_imports(text: str):
    stream = tokens(text)
    window = deque(islice(stream, 4))
    while len(window) > 1:
        word = window[0].text if window[0].kind == "word" else ""
        following = window[1]
        # QML/.import, ESM side effects, and ESM import/export ... from.
        if word in {"import", "from"} and following.kind == "string":
            yield following.span, following.text[1:-1]
        elif word == "import" and following.text == "(":
            # Do not treat a computed expression as a verified local path.
            literal = window[2] if len(window) > 2 else None
            closing = window[3] if len(window) > 3 else None
            if (literal is not None and literal.kind == "string"
                    and closing is not None and closing.text == ")"):
                yield literal.span, literal.text[1:-1]
            else:
                yield following.span, ""
        window.popleft()
        window.extend(islice(stream, 1))


def invalid_imports(plugin: Path, source: Path, text: str):
    try:
        yield from _invalid_imports(plugin, source, text)
    except ImportLexError as error:
        yield (error.offset, error.offset + 1), "unsupported lexical input: " + str(error)


def _invalid_imports(plugin: Path, source: Path, text: str):
    approved = approved_import_spans(plugin.parent, source, text)
    for span, imported in quoted_imports(text):
        if span in approved:
            continue
        if (not imported or any(char in imported for char in ("\\", "%", ":"))
                or imported.startswith("/") or posixpath.normpath(imported) != imported):
            yield span, imported
            continue
        resolved = (source.parent / imported).resolve(strict=False)
        if not resolved.is_relative_to(plugin):
            yield span, imported


def module_present(root: Path, module: Path = MODULE,
                   members: frozenset[str] = MODULE_FILES) -> bool:
    """Require an exact regular sibling module with no symlinked component."""
    current = root
    for part in module.parts:
        current /= part
        if current.is_symlink() or not current.is_dir():
            return False
    names = set()
    for entry in current.iterdir():
        if entry.name not in members or entry.is_symlink() or not entry.is_file():
            return False
        names.add(entry.name)
    return names == members


def _approved_module_import(root: Path, source: Path, text: str, *,
                            module: Path, members: frozenset[str],
                            importers: frozenset[str], alias: str,
                            actual_imports: set[tuple[int, int]]) -> set[tuple[int, int]]:
    try:
        relative = source.relative_to(root).as_posix()
    except ValueError:
        return set()
    if relative not in importers or not module_present(root, module, members):
        return set()
    imported = Path(os.path.relpath(root / module, source.parent)).as_posix()
    pattern = re.compile(r'^[ \t]*import[ \t]+(?P<literal>"' + re.escape(imported)
        + r'")[ \t]+as[ \t]+' + re.escape(alias) + r'[ \t]*\r?$', re.MULTILINE)
    matches = [match for match in pattern.finditer(text)
               if match.span("literal") in actual_imports]
    return {matches[0].span("literal")} if len(matches) == 1 else set()


def approved_import_spans(root: Path, source: Path, text: str) -> set[tuple[int, int]]:
    """Return quoted spans for exact declared cooperative QML imports.

An identical string used as a source URL or command is not exempt. Different
spellings, aliases, importer paths and copies elsewhere remain subject to the
ordinary boundary checks.
"""
    if source.is_symlink() or not source.is_file():
        return set()
    for parent in source.parents:
        if parent == root:
            break
        if parent.is_symlink():
            return set()
    try:
        actual_imports = {span for span, _ in quoted_imports(text)}
    except ImportLexError:
        return set()
    return (
        _approved_module_import(
            root, source, text, module=MODULE, members=MODULE_FILES,
            importers=IMPORTERS, alias="SuiteRuntime",
            actual_imports=actual_imports)
        | _approved_module_import(
            root, source, text, module=PRESENTATION_MODULE,
            members=PRESENTATION_MODULE_FILES,
            importers=PRESENTATION_IMPORTERS, alias="Presentation",
            actual_imports=actual_imports)
    )
