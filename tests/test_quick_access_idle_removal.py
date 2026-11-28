from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class QuickAccessIdleRemovalTests(unittest.TestCase):
    def test_quick_access_widget_has_no_idle_control_and_keeps_picker_actions(self):
        widget = (ROOT / "shinigami.quick-access/BarWidget.qml").read_text()
        for retired in (
            "IdleInhibitor",
            "idleInhibited",
            "toggleIdleInhibitor",
            'label: "IDLE"',
            "Idle inhibited:",
            "0xF06E8",
            "0xF06E9",
            "nerdGlyph",
            "inactiveOpacity",
        ):
            with self.subTest(retired=retired):
                self.assertFalse(retired in widget, f"retired token remains: {retired}")
        self.assertIn('tooltip: "Left: Screenshots  Right: Videos"', widget)
        self.assertIn('label: "MEDIA"', widget)
        self.assertIn('label: "THEME"', widget)
        self.assertIn('root.toggleMode(button === Qt.RightButton ? "videos" : "screenshots")', widget)
        self.assertIn('root.toggleMode("theme")', widget)

    def test_quick_access_service_has_no_idle_dependency_or_ipc_field(self):
        service = (ROOT / "shinigami.quick-access/Service.qml").read_text()
        for retired in (
            "idleService",
            "localIdleInhibited",
            "idleInhibited",
            "toggleIdleInhibitor",
            "setIdleEnabled",
        ):
            with self.subTest(retired=retired):
                self.assertFalse(retired in service, f"retired token remains: {retired}")
        self.assertIn('target: "shinigami-picker"', service)
        for mode in ("theme", "screenshots", "videos"):
            self.assertIn(f'function {mode}(): void', service)
        self.assertIn('["theme", "wallpaper", "screenshots", "videos"]', service)

    def test_current_manifest_and_docs_describe_picker_features_only(self):
        manifest = json.loads((ROOT / "shinigami.quick-access/manifest.json").read_text())
        descriptions = [manifest["description"], manifest["barWidget"]["description"]]
        for description in descriptions:
            self.assertNotIn("idle", description.lower())
            self.assertRegex(description.lower(), r"theme|picker")
            self.assertRegex(description.lower(), r"screenshot|image|media")
            self.assertRegex(description.lower(), r"video|media")

        docs = (
            ROOT / "README.md",
            ROOT / "docs/plugins/README.md",
            ROOT / "docs/shinigami-port.md",
        )
        for path in docs:
            with self.subTest(path=path.relative_to(ROOT)):
                text = path.read_text().lower()
                self.assertNotRegex(text, r"quick access[^\n]*idle inhibit")

    def test_host_owned_idle_behavior_remains_independent(self):
        status = (ROOT / "shinigami.status/Service.qml").read_text()
        indicators = (ROOT / "shinigami.center/StatusIndicators.qml").read_text()
        bar = (ROOT / "shinigami.bar/Bar.qml").read_text()
        self.assertIn('firstPartyServiceFor("omarchy.idle")', status)
        self.assertIn("setIdleEnabled(stayAwake)", status)
        self.assertIn("statusService.stayAwake", indicators)
        self.assertIn("screensaverStartedThisCycle", bar)


if __name__ == "__main__":
    unittest.main()
