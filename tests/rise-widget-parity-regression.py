#!/usr/bin/env python3
"""Static Rise parity contracts for wallpaper manager and indicators.

Run from the repository root:

    python3 tests/rise-widget-parity-regression.py

This is source evidence only. It does not claim Wayland hover, pointer, or
multi-output behavior.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WALLPAPER = ROOT / "shinigami.wallpaper-manager"
INDICATORS = ROOT / "shinigami.indicators"
STATUS = ROOT / "shinigami.status" / "Service.qml"

TOOLTIP = (
    "Wallpaper manager · click to open · "
    "middle-click for next on all displays"
)


def read(path: Path) -> str:
    if not path.is_file():
        raise AssertionError(f"missing source file: {path}")
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def check_wallpaper() -> None:
    logic = read(WALLPAPER / "rise/logic/WallpaperManagerQuickWidgetLogic.js")
    rise_root = read(WALLPAPER / "rise/RiseRoot.qml")
    host = read(WALLPAPER / "BarWidget.qml")
    mixin = read(WALLPAPER / "rise/components/TooltipMixin.qml")

    require("Qt.RightButton" not in logic, "wallpaper logic still accepts right-click")
    require(
        "openWallpaperSettings" not in logic,
        "wallpaper logic still routes to settings",
    )
    require(
        "wallpaperManagerServiceApi.nextAll()" in logic,
        "wallpaper middle-click lost nextAll()",
    )
    require(
        "toggleWallpaperManager(riseOwner.screen, riseOwner)" in logic,
        "wallpaper left-click lost toggleWallpaperManager()",
    )
    require(
        "openWallpaperSettings" not in rise_root,
        "wallpaper Rise facade still exposes a settings route",
    )
    require(
        "openSettings" not in host
        and "wallpaperomarchymanager" not in host,
        "wallpaper host still exposes the non-Rise settings route",
    )
    require(
        "root.showTooltip(owner, text)" in mixin
        and "root.hideTooltip(owner)" in mixin,
        "wallpaper tooltip owner contract drifted",
    )

    for variant in ("v1", "v2"):
        source = read(
            WALLPAPER / f"rise/{variant}/WallpaperManagerQuickWidget.qml"
        )
        require(
            f'readonly property string tooltipText: "{TOOLTIP}"' in source,
            f"{variant} wallpaper tooltip text drifted from Rise",
        )
        require(
            "acceptedButtons: Qt.LeftButton | Qt.MiddleButton" in source,
            f"{variant} wallpaper accepted buttons drifted from Rise",
        )
        require(
            "onEntered: tip.show()" in source
            and "onExited: tip.hide()" in source,
            f"{variant} wallpaper hover-tooltip wiring drifted",
        )
        require(
            "TooltipMixin { id: tip; root: control.root; owner: control;"
            in source,
            f"{variant} wallpaper tooltip owner is not the widget",
        )

    v2 = read(
        WALLPAPER / "rise/v2/WallpaperManagerQuickWidget.qml"
    )
    require(
        "enabled: !control.root.barUnlocked" in v2,
        "V2 wallpaper lost its unlocked-bar edit guard",
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
        print(f"rise widget parity regression failed: {error}", file=sys.stderr)
        return 1
    print("rise widget parity regression passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
