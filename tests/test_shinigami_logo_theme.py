import hashlib
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTROL = ROOT / "shinigami.control-center"
ASSETS = CONTROL / "assets"
ORIGINAL = ASSETS / "shinigami-icon-hikiryo.svg"
SOURCE_ART = ROOT / "tests" / "fixtures" / "shinigami-shell-transparente.svg"
SOURCE_ART_SHA256 = "38be8bbfcbb97a786bae1d76d26e269ed3be057549f54550e6b447a36982b026"


class ShinigamiLogoThemeTests(unittest.TestCase):
    def test_logo_uses_the_same_icon_style_as_its_neighbors(self) -> None:
        bar = (CONTROL / "BarWidget.qml").read_text()
        settings = (CONTROL / "LogoSettingsPage.qml").read_text()
        self.assertRegex(bar, r"ShinigamiGlyph \{[^}]*size: root\.iconSize\(\"shinigami\"\)[^}]*ink: root\.widgetInk")
        self.assertEqual(settings.count("ShinigamiGlyph {"), 2)
        self.assertEqual(settings.count("size: Commons.Style.font.iconLarge * root.uiScale"), 2)
        self.assertEqual(settings.count("ink: root.foreground"), 2)

    def test_original_shared_logo_asset_is_unchanged(self) -> None:
        self.assertEqual(
            hashlib.sha256(ORIGINAL.read_bytes()).hexdigest(),
            "d5729e61a986661148728f5da3090a2edfaef4834a5e7642d440c8b1c2f8c162",
        )

    def test_launcher_and_previews_use_supplied_shape_but_plugins_keep_original(self) -> None:
        bar = (CONTROL / "BarWidget.qml").read_text(encoding="utf-8")
        settings = (CONTROL / "LogoSettingsPage.qml").read_text(encoding="utf-8")
        semantic = (CONTROL / "SemanticPreviewImage.qml").read_text(encoding="utf-8")
        provider = (CONTROL / "PluginProviderSummary.qml").read_text(encoding="utf-8")
        catalog = (CONTROL / "PluginCatalogPage.qml").read_text(encoding="utf-8")
        direct_asset = ASSETS / "shinigami-shell-transparente.svg"
        source_bytes = SOURCE_ART.read_bytes()
        self.assertEqual(hashlib.sha256(source_bytes).hexdigest(), SOURCE_ART_SHA256)
        original_color = b'color="#e40518"'
        self.assertEqual(source_bytes.count(original_color), 1)
        self.assertEqual(
            direct_asset.read_bytes(),
            source_bytes.replace(original_color, b'color="#ffffff"', 1),
        )
        glyph = (CONTROL / "ShinigamiGlyph.qml").read_text()
        self.assertIn('assets/shinigami-shell-transparente.svg', glyph)
        self.assertIn('ctx.drawImage(source, 0, 0, width, height)', glyph)
        self.assertIn('ctx.globalCompositeOperation = "source-in"', glyph)
        self.assertIn('ctx.fillStyle = ink', glyph)
        self.assertEqual(bar.count("ShinigamiGlyph {"), 1)
        self.assertEqual(semantic.count("ShinigamiGlyph {"), 2)
        self.assertIn('icon === "shinigami"', settings)
        self.assertIn('modelData === "shinigami"', settings)
        self.assertIn('visible: root.compact && root.semanticRoute === "logo"', semantic)
        self.assertIn('visible: root.semanticRoute === "logo" && !root.compact', semantic)
        self.assertIn('iconSource: Qt.resolvedUrl("assets/shinigami-icon-hikiryo.svg")', provider)
        self.assertNotIn("ThemeShinigamiLogo", provider)
        self.assertIn("PluginProviderSummary {", catalog)


if __name__ == "__main__":
    unittest.main()
