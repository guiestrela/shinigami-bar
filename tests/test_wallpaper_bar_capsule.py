from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class WallpaperBarCapsuleTest(unittest.TestCase):
    def test_wallpaper_bar_owns_one_v1_pill_like_its_neighbor_widgets(self):
        wallpaper = (ROOT / "shinigami.wallpaper-manager/BarWidget.qml").read_text()
        quick_access = (ROOT / "shinigami.quick-access/BarWidget.qml").read_text()
        network = (ROOT / "shinigami.network/BarWidget.qml").read_text()
        group_slot = (ROOT / "shinigami.bar/core/GroupSlot.qml").read_text()
        bar = (ROOT / "shinigami.bar/Bar.qml").read_text()

        # Standalone suite widgets opt out of the GroupSlot fallback, so the
        # wallpaper widget must provide exactly one surface of its own.
        self.assertIn('"shinigami.wallpaper-manager"', bar[
            bar.index("function isStandaloneSuiteWidget"):])
        self.assertIn("root.dynamicV1Group && !root.dynamicV1WidgetOwnsSurface",
                      group_slot)
        self.assertEqual(wallpaper.count("Presentation.PillSurface {"), 1)

        # Match the widget-owned V1 recipe used by Quick Access and Network.
        self.assertIn("Presentation.PillSurface {", quick_access)
        self.assertIn("Presentation.PillSurface {", network)
        self.assertLess(wallpaper.index("Presentation.PillSurface {"),
                        wallpaper.index("  BarIconButton {"))
        for required in (
            "tokenSource: root.panelTokens",
            "settings: root.settings",
            "v1AppearanceEnabled: true",
            "anchors.fill: parent",
            "root.panelTokens.pillHeight",
            "bar: root.bar",
        ):
            with self.subTest(binding=required):
                self.assertIn(required, wallpaper)
