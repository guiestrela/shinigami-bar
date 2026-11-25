#!/usr/bin/env python3
"""Static contracts for the substituted wallpaper widget and indicators.

Run from the repository root:

    python3 tests/rise-widget-parity-regression.py

This is source evidence only. It does not claim Wayland hover, pointer, or
multi-output behavior.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WALLPAPER = ROOT / "shinigami.wallpaper-manager"
INDICATORS = ROOT / "shinigami.indicators"
STATUS = ROOT / "shinigami.status" / "Service.qml"


def read(path: Path) -> str:
    if not path.is_file():
        raise AssertionError(f"missing source file: {path}")
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def check_wallpaper() -> None:
    manifest = json.loads(read(WALLPAPER / "manifest.json"))
    host = read(WALLPAPER / "BarWidget.qml")
    background = read(WALLPAPER / "Background.qml")

    require(
        manifest.get("id") == "shinigami.wallpaper-manager",
        "installed wallpaper plugin was not renamed to the Shinigami ID",
    )
    require(
        manifest.get("name") == "Wallpapers"
        and manifest.get("barWidget", {}).get("displayName") == "Wallpapers",
        "wallpaper plugin visible name drifted from Wallpapers",
    )
    require(
        manifest.get("kinds") == ["bar-widget", "service"],
        "wallpaper plugin lost its bar-widget/service ownership",
    )
    require(
        manifest.get("entryPoints", {}).get("barWidget") == "BarWidget.qml"
        and manifest.get("entryPoints", {}).get("service") == "Background.qml",
        "wallpaper plugin entry points drifted from the substituted plugin",
    )
    require(
        'moduleName: "shinigami.wallpaper-manager"' in host
        and 'ipcTarget: "shinigami.wallpaper-manager"' in host,
        "wallpaper bar widget identity is not the Shinigami plugin ID",
    )
    require(
        "if (buttonCode === Qt.MiddleButton) root.nextImage()\n"
        "      else root.toggle()" in host,
        "wallpaper click path lost left-toggle or middle-click next",
    )
    require(
        'text: "Wallpapers"' in host
        and 'readonly property string previewTitle: "Wallpapers"'
        ' + (version === "" ? "" : " v" + version)' in host,
        "wallpaper panel labels are not Wallpapers",
    )
    require(
        "openWallpaperSettings" not in host
        and "host.picker" not in host
        and "wallpaperomarchymanager" not in host.lower(),
        "wallpaper widget still routes to the removed third-party picker",
    )
    require(
        '(manifest && manifest.id) || "shinigami.wallpaper-manager"' in background
        and 'target: "background"' in background,
        "wallpaper service identity or background IPC target drifted",
    )
    for name in (
        "Background.qml",
        "BarWidget.qml",
        "WallpaperRenderer.qml",
        "publish-current-background.py",
        "stage-pinned-media.py",
    ):
        require((WALLPAPER / name).is_file(), f"missing substituted file: {name}")
    for path in WALLPAPER.iterdir():
        if path.is_file() and path.suffix.lower() != ".png":
            text = path.read_text(encoding="utf-8")
            require(
                "io.github.guiestrela.wallpaperomarchymanager" not in text,
                f"legacy plugin ID survives in {path.name}",
            )


def check_indicators() -> None:
    widget = read(INDICATORS / "rise/components/IndicatorsWidget.qml")
    host = read(INDICATORS / "BarWidget.qml")
    service = read(STATUS)

    expected_ids = [
        "PasswordlessSudo",
        "ScreenRecording",
        "RemoteSession",
        "Reminder",
        "NightLight",
        "Dnd",
        "StayAwake",
        "Voxtype",
    ]
    actual_ids = re.findall(r'\{id: "([A-Za-z]+)"', widget)
    require(
        actual_ids == expected_ids,
        f"indicator entry model drifted: {actual_ids}",
    )
    require(
        widget.count('{id: "Voxtype"') == 1,
        "Voxtype must remain the only Shinigami-specific indicator",
    )
    require(
        "available: false" in widget,
        "RemoteSession lost its display-only availability",
    )
    require(
        "Qt.ArrowCursor" in widget,
        "RemoteSession lost its non-action cursor",
    )
    require(
        "available: coordinator.notificationsAvailable" in widget
        and "available: coordinator.idleAvailable" in widget,
        "indicator availability drifted from Rise backends",
    )
    require(
        "acceptedButtons: indicator.modelData.id === \"Voxtype\"\n"
        "                        ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton"
        in widget,
        "only Voxtype may accept right-click",
    )
    require(
        "widget.coordinator.activate(indicator.modelData.id, mouse.button)" in widget,
        "indicator activation lost button forwarding",
    )

    for action in (
        "ScreenRecording",
        "NightLight",
        "Reminder",
        "PasswordlessSudo",
        "Dnd",
        "StayAwake",
        "Voxtype",
    ):
        require(
            f'case "{action}":' in host,
            f"indicator coordinator lost {action}",
        )
    require(
        'case "RemoteSession":' not in host,
        "display-only RemoteSession gained an action",
    )
    require(
        'reminders && widgetRoot.statusService.reminderTooltip\n'
        '      ? widgetRoot.statusService.reminderTooltip : "Set a reminder"'
        in host,
        "empty reminder tooltip lost its Rise fallback",
    )
    require(
        "idleAvailable" in host
        and "notificationsAvailable" in host,
        "indicator coordinator lost backend availability flags",
    )
    require(
        'runFallback(service, ["omarchy-toggle-idle"])' in host
        and 'runFallback(service, ["omarchy-toggle-notification-silencing"])'
        in host,
        "indicator coordinator lost Rise's backend-free toggles",
    )
    require(
        "function runFallback(service, command)" in host
        and "Qt.callLater(service.refreshIndicators)" in host,
        "indicator fallback lost its post-action refresh",
    )

    require(
        "readonly property bool idleAvailable: !!idleService" in service
        and "readonly property bool notificationsAvailable:"
        " notificationAdapter.available" in service,
        "status service lost indicator availability flags",
    )
    require(
        "remoteSessionService.refresh()" in service,
        "status service lost Rise remote-session refresh",
    )
    require(
        'IpcHandler { target: "omarchy.indicators" }' not in service,
        "status service must not duplicate the host-owned indicators IPC target",
    )


def main() -> int:
    try:
        check_wallpaper()
        check_indicators()
    except AssertionError as error:
        print(f"wallpaper/indicator parity regression failed: {error}", file=sys.stderr)
        return 1
    print("wallpaper/indicator parity regression passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
