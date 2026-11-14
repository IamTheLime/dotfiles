"""Validate the portable palette library and its existing Ember Grove mappings."""

import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PaletteTests(unittest.TestCase):
    def test_palette_references(self):
        files = list((ROOT / "palettes").glob("*/palette.json"))
        self.assertTrue(files)
        for file in files:
            with self.subTest(palette=file.parent.name):
                palette = json.loads(file.read_text())
                self.assertEqual(palette["format_version"], 1)
                self.assertEqual(palette["id"], file.parent.name)
                self.assertTrue((file.parent / "README.md").is_file())
                colors = palette["colors"]
                for color in colors.values():
                    self.assertRegex(color, r"^#[0-9a-fA-F]{6}$")

                def check_roles(roles):
                    for role in roles.values():
                        if isinstance(role, dict):
                            check_roles(role)
                        else:
                            self.assertIn(role, {*colors, "inherit"})

                check_roles(palette["roles"])
                self.assertEqual(len(palette["ansi"]), 16)
                for name in palette["ansi"] + palette["mode_cycle"]:
                    self.assertIn(name, colors)
                self.assertIn(palette["background_policy"]["opaque_fallback"], colors)
                for path, styles in palette["typography"].items():
                    role = palette["roles"]
                    for part in path.split("."):
                        role = role[part]
                    self.assertIsInstance(role, str)
                    self.assertTrue(set(styles) <= {"bold", "italic", "underline"})

    def test_ember_grove_matches_existing_themes(self):
        palette = json.loads((ROOT / "palettes/ember-grove/palette.json").read_text())
        colors = palette["colors"]
        self.assertEqual(palette["roles"]["surface"]["canvas"], "inherit")
        self.assertEqual(palette["background_policy"]["default"], "inherit")
        self.assertNotEqual(colors[palette["roles"]["text"]["strong"]], colors[palette["roles"]["text"]["body"]])

        lua = (ROOT / "dotfiles/nvim/themes/ember-grove/lua/ember-grove/init.lua").read_text()
        table = re.search(r"M\.palette = \{(.*?)\n\}", lua, re.S)[1]
        for name, color in re.findall(r'^\s+(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"', table, re.M):
            self.assertEqual(colors[name], color, f"Neovim swatch drift: {name}")

        ghostty = (ROOT / "dotfiles/ghostty/themes/Ember Grove").read_text()
        slots = dict(re.findall(r"^palette = (\d+)=(#[0-9a-fA-F]{6})$", ghostty, re.M))
        self.assertEqual(len(slots), 16)
        for index, name in enumerate(palette["ansi"]):
            self.assertEqual(colors[name], slots[str(index)], f"ANSI slot {index} drift")

        opencode = json.loads((ROOT / "dotfiles/opencode/themes/ember-grove.json").read_text())
        for token, role in {"text": "body", "strong": "strong", "emphasis": "emphasis", "heading": "heading", "link": "link"}.items():
            self.assertEqual(opencode["base"]["markdown"][token], colors[palette["roles"]["text"][role]])


if __name__ == "__main__":
    unittest.main()
