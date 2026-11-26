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


def qml_image_blocks(source: str) -> list[tuple[str, str]]:
    blocks = []
    pattern = re.compile(r"(?m)^[ ]*(Image|FlatTintedImage)[ ]*[{]")
    for match in pattern.finditer(source):
        opening = source.find("{", match.start())
        depth = 0
        for index in range(opening, len(source)):
            if source[index] == "{":
                depth += 1
            elif source[index] == "}":
                depth -= 1
                if depth == 0:
                    blocks.append((match.group(1), source[match.start():index + 1]))
                    break
    return blocks


class ShinigamiLogoThemeTests(unittest.TestCase):
    def test_original_shared_logo_asset_is_unchanged(self) -> None:
        self.assertEqual(
            hashlib.sha256(ORIGINAL.read_bytes()).hexdigest(),
            "d5729e61a986661148728f5da3090a2edfaef4834a5e7642d440c8b1c2f8c162",
        )

    def test_launcher_and_logo_previews_use_supplied_svg_directly_but_plugins_keep_svg(self) -> None:
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
        for name, source, expected_count in (
            ("launcher", bar, 1),
            ("Logo settings", settings, 2),
            ("semantic Logo previews", semantic, 2),
        ):
            logo_images = [
                (kind, block) for kind, block in qml_image_blocks(source)
                if 'assets/shinigami-shell-transparente.svg' in block
            ]
            self.assertEqual(len(logo_images), expected_count, name)
            for kind, block in logo_images:
                self.assertEqual(kind, "Image", name)
                self.assertIn("fillMode: Image.PreserveAspectFit", block, name)
                self.assertFalse(
                    any(line.strip().startswith("tint:") for line in block.splitlines()),
                    name,
                )
            self.assertNotIn("ThemeShinigamiLogo {", source, name)
        launcher_images = [
            block for kind, block in qml_image_blocks(bar)
            if kind == "Image" and 'assets/shinigami-shell-transparente.svg' in block
        ]
        self.assertIn("width: 18", launcher_images[0])
        self.assertIn("height: 18", launcher_images[0])
        self.assertIn('icon === "shinigami"', settings)
        self.assertIn('modelData === "shinigami"', settings)
        self.assertIn('visible: root.compact && root.semanticRoute === "logo"', semantic)
        self.assertIn('visible: root.semanticRoute === "logo" && !root.compact', semantic)
        self.assertIn('iconSource: Qt.resolvedUrl("assets/shinigami-icon-hikiryo.svg")', provider)
        self.assertNotIn("ThemeShinigamiLogo", provider)
        self.assertIn("PluginProviderSummary {", catalog)


if __name__ == "__main__":
    unittest.main()
