import hashlib
import os
import re
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTROL = ROOT / "shinigami.control-center"
ASSETS = CONTROL / "assets"
ORIGINAL = ASSETS / "shinigami-icon-hikiryo.svg"
SOURCE_ART = ROOT / "tests" / "fixtures" / "shinigami-shell-transparente.svg"
SOURCE_ART_SHA256 = "38be8bbfcbb97a786bae1d76d26e269ed3be057549f54550e6b447a36982b026"
ACCENT_MASK_PNG_SHA256 = "b6883febac1bd7668a7292851c1efef6c3a4626d781b07f21750edc5586ee371"
INK_MASK_PNG_SHA256 = "82d66cc508a2a0585ca7b4a605bb399f032e7fd6f33b4e9468c23b3ccef1f956"
ACCENT_MASK = ROOT / "tests" / "fixtures" / "shinigami-icon-hikiryo-accent-mask.svg"
INK_MASK = ROOT / "tests" / "fixtures" / "shinigami-icon-hikiryo-ink-mask.svg"
COMPONENT = CONTROL / "ThemeShinigamiLogo.qml"
TEMPLATE = ROOT / "tests" / "shinigami-logo-theme-render.qml"
OUTPUT_DIR = Path(
    os.environ.get(
        "SHINIGAMI_LOGO_TEST_OUTPUT",
        str(Path(tempfile.gettempdir()) / "shinigami-logo-theme"),
    )
)


def element_id_set(path: Path) -> set[str]:
    root = ET.parse(path).getroot()
    return {node.attrib["id"] for node in root.iter() if "id" in node.attrib}


def path_data_by_id(path: Path) -> dict[str, str]:
    root = ET.parse(path).getroot()
    return {
        node.attrib["id"]: node.attrib["d"]
        for node in root.iter()
        if node.tag.rsplit("}", 1)[-1] == "path"
        and "id" in node.attrib and "d" in node.attrib
    }


def palette_pixel_count(image, target: tuple[int, int, int], tolerance: int = 60) -> int:
    return sum(
        1
        for red, green, blue, alpha in image.get_flattened_data()
        if alpha >= 96
        and max(abs(red - target[0]), abs(green - target[1]), abs(blue - target[2])) <= tolerance
    )


def transparent_pixel_count(image) -> int:
    return sum(1 for pixel in image.get_flattened_data() if pixel[3] == 0)


class ShinigamiLogoThemeTests(unittest.TestCase):
    def test_original_shared_logo_asset_is_unchanged(self) -> None:
        self.assertEqual(
            hashlib.sha256(ORIGINAL.read_bytes()).hexdigest(),
            "d5729e61a986661148728f5da3090a2edfaef4834a5e7642d440c8b1c2f8c162",
        )

    def test_masks_separate_accent_from_ink_and_omit_the_background_disc(self) -> None:
        self.assertTrue(ACCENT_MASK.is_file(), "accent mask is missing")
        self.assertTrue(INK_MASK.is_file(), "ink mask is missing")
        source_root = ET.parse(SOURCE_ART).getroot()
        source_view_box = source_root.attrib["viewBox"]
        accent_root = ET.parse(ACCENT_MASK).getroot()
        ink_root = ET.parse(INK_MASK).getroot()
        for root in (source_root, accent_root, ink_root):
            self.assertEqual(root.attrib["viewBox"], source_view_box)
            ids = {node.attrib["id"] for node in root.iter() if "id" in node.attrib}
            self.assertNotIn("fundo", ids)
            for node in root.iter():
                self.assertNotIn(node.tag.rsplit("}", 1)[-1].lower(), {"image", "script", "foreignobject"})
                for key, value in node.attrib.items():
                    if key.rsplit("}", 1)[-1].lower() in {"href", "src"}:
                        self.assertTrue(value.startswith("#"), value)
                    for reference in re.findall(r"url\(([^)]+)\)", value):
                        reference = reference.strip().strip(chr(34) + chr(39))
                        self.assertTrue(reference.startswith("#"), reference)
                        self.assertIn(reference[1:], ids, reference)
        accent_ids = element_id_set(ACCENT_MASK)
        ink_ids = element_id_set(INK_MASK)
        self.assertTrue({"enso", "pincelada", "fita"}.issubset(accent_ids))
        self.assertTrue({"lamina-e-cabo-da-foice", "lamina-e-empunhadura-da-katana"}.issubset(ink_ids))
        self.assertNotIn("lamina-e-cabo-da-foice", accent_ids)
        self.assertNotIn("pincelada", ink_ids)

    def test_masks_are_regenerated_from_the_supplied_transparent_art(self) -> None:
        self.assertEqual(
            hashlib.sha256(SOURCE_ART.read_bytes()).hexdigest(), SOURCE_ART_SHA256
        )
        source_paths = path_data_by_id(SOURCE_ART)
        source_rules = {
            node.attrib["id"]: node.attrib.get("fill-rule")
            for node in ET.parse(SOURCE_ART).getroot().iter()
            if node.tag.endswith("path") and node.attrib.get("id")
        }
        expected_accent = {key: source_paths[key] for key in ("pincelada", "fita")}
        expected_ink = {
            key: source_paths[key]
            for key in ("lamina-e-cabo-da-foice", "lamina-e-empunhadura-da-katana")
        }
        for mask_path, expected_paths in (
            (ACCENT_MASK, expected_accent),
            (INK_MASK, expected_ink),
        ):
            mask_root = ET.parse(mask_path).getroot()
            self.assertEqual(mask_root.attrib.get("data-source-sha256"), SOURCE_ART_SHA256)
            self.assertEqual(path_data_by_id(mask_path), expected_paths)
            mask_rules = {
                node.attrib["id"]: node.attrib.get("fill-rule")
                for node in mask_root.iter()
                if node.tag.endswith("path") and node.attrib.get("id")
            }
            self.assertEqual(mask_rules, {key: source_rules[key] for key in expected_paths})

    def test_reusable_component_tints_the_two_masks_with_canvas(self) -> None:
        self.assertTrue(COMPONENT.is_file(), "production ThemeShinigamiLogo.qml is missing")
        source = COMPONENT.read_text(encoding="utf-8")
        self.assertEqual(source.count("Canvas {"), 2)
        self.assertIn('shinigami-icon-hikiryo-accent-mask.png', source)
        self.assertIn('shinigami-icon-hikiryo-ink-mask.png', source)
        self.assertIn('globalCompositeOperation = "source-in"', source)
        self.assertNotIn("ShaderEffect", source)
        self.assertNotIn("FlatTintedImage", source)

    def test_raster_masks_are_distinct_transparent_alpha_layers(self) -> None:
        from PIL import Image, ImageChops

        accent_path = ASSETS / "shinigami-icon-hikiryo-accent-mask.png"
        ink_path = ASSETS / "shinigami-icon-hikiryo-ink-mask.png"
        self.assertEqual(hashlib.sha256(accent_path.read_bytes()).hexdigest(), ACCENT_MASK_PNG_SHA256)
        self.assertEqual(hashlib.sha256(ink_path.read_bytes()).hexdigest(), INK_MASK_PNG_SHA256)
        accent = Image.open(accent_path).convert("RGBA")
        ink = Image.open(ink_path).convert("RGBA")
        self.assertEqual(accent.size, (640, 640))
        self.assertEqual(ink.size, (640, 640))
        self.assertGreater(transparent_pixel_count(accent), 0)
        self.assertGreater(transparent_pixel_count(ink), 0)
        self.assertIsNotNone(ImageChops.difference(accent.getchannel("A"), ink.getchannel("A")).getbbox())

    def test_launcher_and_logo_previews_use_the_theme_component_but_plugins_keep_svg(self) -> None:
        bar = (CONTROL / "BarWidget.qml").read_text(encoding="utf-8")
        settings = (CONTROL / "LogoSettingsPage.qml").read_text(encoding="utf-8")
        semantic = (CONTROL / "SemanticPreviewImage.qml").read_text(encoding="utf-8")
        provider = (CONTROL / "PluginProviderSummary.qml").read_text(encoding="utf-8")
        catalog = (CONTROL / "PluginCatalogPage.qml").read_text(encoding="utf-8")
        self.assertEqual(bar.count("ThemeShinigamiLogo {"), 2)
        self.assertEqual(bar.count("accent: root.tokens.seal"), 2)
        self.assertEqual(
            bar.count("ink: root.bar ? root.bar.foreground : root.widgetInk"), 1
        )
        self.assertEqual(bar.count("ink: root.widgetInk"), 1)
        self.assertEqual(settings.count("ThemeShinigamiLogo {"), 2)
        self.assertEqual(settings.count("height: width\n          accent: root.accent\n          ink: root.foreground"), 2)
        self.assertEqual(settings.count("ink: root.foreground"), 2)
        self.assertEqual(semantic.count("ThemeShinigamiLogo {"), 2)
        self.assertIn('visible: root.compact && root.semanticRoute === "logo"', semantic)
        self.assertIn('visible: root.semanticRoute === "logo" && !root.compact', semantic)
        self.assertIn('iconSource: Qt.resolvedUrl("assets/shinigami-icon-hikiryo.svg")', provider)
        self.assertNotIn("ThemeShinigamiLogo", provider)
        self.assertIn("PluginProviderSummary {", catalog)

    def test_production_component_renders_palette_change_in_qt_same_process(self) -> None:
        self.assertTrue(COMPONENT.is_file(), "production ThemeShinigamiLogo.qml is missing")
        self.assertTrue(TEMPLATE.is_file(), "Qt render harness is missing")
        import PIL.Image as Image
        from PIL import ImageChops

        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        dark_path = OUTPUT_DIR / "component-dark-18x18.png"
        light_path = OUTPUT_DIR / "component-light-18x18.png"
        qml = TEMPLATE.read_text(encoding="utf-8")
        qml = qml.replace("__COMPONENT_URL__", COMPONENT.as_uri())
        qml = qml.replace("__DARK_CAPTURE__", str(dark_path))
        qml = qml.replace("__LIGHT_CAPTURE__", str(light_path))
        qml_path = None
        command = [os.environ.get("QMLSCENE_BIN", "/usr/lib/qt6/bin/qmlscene")]
        env = os.environ.copy()
        env.update({"QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"})
        try:
            with tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", suffix=".qml", prefix="logo-render-",
                dir=OUTPUT_DIR, delete=False
            ) as handle:
                handle.write(qml)
                qml_path = Path(handle.name)
            command.append(str(qml_path))
            result = subprocess.run(command, capture_output=True, text=True, env=env, timeout=20)
            log = [
                "command=QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software " + " ".join(command),
                "exit=" + str(result.returncode),
                "stdout:",
                result.stdout,
                "stderr:",
                result.stderr,
            ]
            (OUTPUT_DIR / "qt-render.log").write_text("\n".join(log) + "\n", encoding="utf-8")
            self.assertEqual(result.returncode, 0, (result.stdout + result.stderr)[-8000:])
        finally:
            if qml_path is not None:
                qml_path.unlink(missing_ok=True)

        dark = Image.open(dark_path).convert("RGBA")
        light = Image.open(light_path).convert("RGBA")
        self.assertEqual(dark.size, (18, 18))
        self.assertEqual(light.size, (18, 18))
        self.assertGreater(palette_pixel_count(dark, (239, 68, 68)), 0, "dark accent pixels missing")
        self.assertGreater(palette_pixel_count(dark, (244, 244, 245)), 0, "dark ink pixels missing")
        self.assertGreater(palette_pixel_count(light, (37, 99, 235)), 0, "light accent pixels missing")
        self.assertGreater(palette_pixel_count(light, (31, 41, 55)), 0, "light ink pixels missing")
        self.assertGreater(transparent_pixel_count(dark), 0, "dark background is not transparent")
        self.assertGreater(transparent_pixel_count(light), 0, "light background is not transparent")
        self.assertIsNone(ImageChops.difference(dark.getchannel("A"), light.getchannel("A")).getbbox())
        self.assertIsNotNone(ImageChops.difference(dark.convert("RGB"), light.convert("RGB")).getbbox())

        from PIL import ImageDraw, ImageFont
        comparison = Image.new("RGB", (420, 144), "#f8fafc")
        draw = ImageDraw.Draw(comparison)
        draw.rectangle((0, 0, 199, 143), fill="#131821")
        draw.rectangle((220, 0, 419, 143), fill="#f8fafc")
        font = ImageFont.load_default()
        draw.text((10, 8), "DARK - accent #EF4444 - ink #F4F4F5", fill="#f4f4f5", font=font)
        draw.text((230, 8), "LIGHT - accent #2563EB - ink #1F2937", fill="#1f2937", font=font)
        dark_zoom = dark.resize((108, 108), Image.Resampling.NEAREST)
        light_zoom = light.resize((108, 108), Image.Resampling.NEAREST)
        comparison.paste(dark_zoom, (46, 29), dark_zoom)
        comparison.paste(light_zoom, (266, 29), light_zoom)
        comparison_path = OUTPUT_DIR / "component-comparison.png"
        comparison.save(comparison_path)

        with (OUTPUT_DIR / "qt-render.log").open("a", encoding="utf-8") as handle:
            handle.write(f"dark_size={dark.width}x{dark.height}\n")
            handle.write(f"light_size={light.width}x{light.height}\n")
            handle.write(f"dark_accent_pixels={palette_pixel_count(dark, (239, 68, 68))}\n")
            handle.write(f"dark_ink_pixels={palette_pixel_count(dark, (244, 244, 245))}\n")
            handle.write(f"light_accent_pixels={palette_pixel_count(light, (37, 99, 235))}\n")
            handle.write(f"light_ink_pixels={palette_pixel_count(light, (31, 41, 55))}\n")
            handle.write(f"dark_transparent_pixels={transparent_pixel_count(dark)}\n")
            handle.write(f"light_transparent_pixels={transparent_pixel_count(light)}\n")
            handle.write("palette_change=same QML item and same Qt process\n")
            handle.write("renderer=QQuick Canvas.Image, Qt Quick software backend\n")
            handle.write(f"dark_capture={dark_path}\n")
            handle.write(f"light_capture={light_path}\n")
            handle.write(f"comparison_capture={comparison_path}\n")
            handle.write(f"dark_sha256={hashlib.sha256(dark_path.read_bytes()).hexdigest()}\n")
            handle.write(f"light_sha256={hashlib.sha256(light_path.read_bytes()).hexdigest()}\n")
            handle.write(f"comparison_sha256={hashlib.sha256(comparison_path.read_bytes()).hexdigest()}\n")
            handle.write(f"source_art={SOURCE_ART}\n")
            handle.write(f"source_art_sha256={hashlib.sha256(SOURCE_ART.read_bytes()).hexdigest()}\n")
            handle.write(f"accent_mask_svg_sha256={hashlib.sha256(ACCENT_MASK.read_bytes()).hexdigest()}\n")
            handle.write(f"ink_mask_svg_sha256={hashlib.sha256(INK_MASK.read_bytes()).hexdigest()}\n")
            handle.write(f"accent_mask_png_sha256={hashlib.sha256((ASSETS / 'shinigami-icon-hikiryo-accent-mask.png').read_bytes()).hexdigest()}\n")
            handle.write(f"ink_mask_png_sha256={hashlib.sha256((ASSETS / 'shinigami-icon-hikiryo-ink-mask.png').read_bytes()).hexdigest()}\n")


if __name__ == "__main__":
    unittest.main()
