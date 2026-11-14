"""Local checks: python3 -m unittest discover -s tests -v."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRATCH = "/tmp/opencode" if Path("/tmp/opencode").is_dir() else None


class OpenCodeThemeTests(unittest.TestCase):
    def test_colors_and_references(self):
        theme = json.loads((ROOT / "dotfiles/opencode/themes/ember-grove.json").read_text())
        tree = {**theme["base"], **theme["dark"]}

        def resolve(path, trail=()):
            self.assertNotIn(path, trail, f"cyclic reference: {path}")
            value = tree
            for part in path.split("."):
                if isinstance(value, str) and value.startswith("$"):
                    value = resolve(value[1:], (*trail, path))
                value = value[part]
            if isinstance(value, str) and value.startswith("$"):
                return resolve(value[1:], (*trail, path))
            return value

        def walk(value):
            if isinstance(value, dict):
                for child in value.values():
                    walk(child)
            elif isinstance(value, str):
                resolved = resolve(value[1:]) if value.startswith("$") else value
                if isinstance(resolved, str):
                    self.assertRegex(resolved, r"^(#[0-9a-fA-F]{6}|transparent)$")

        # categorical is a list of hue names, not a list of colour values.
        walk({key: value for key, value in tree.items() if key != "categorical"})
        for hue in ["gray", "red", "orange", "yellow", "green", "cyan", "blue", "purple"]:
            self.assertEqual(set(resolve(f"hue.{hue}")), {str(n) for n in range(100, 1000, 100)})
        body = resolve("markdown.text")
        self.assertEqual(resolve("background.base"), "transparent", "Ghostty should supply the main background")
        self.assertNotEqual(resolve("text.action.primary.$focused"), "transparent", "focused text must remain visible")
        self.assertNotEqual(resolve("text.action.destructive.base"), "transparent")
        self.assertNotEqual(resolve("markdown.strong"), body, "bold alone is not enough")
        self.assertNotEqual(resolve("markdown.heading"), body)
        for hue in tree["categorical"]:
            self.assertNotEqual(resolve(f"hue.{hue}.200"), body, "mode colours must differ from prose")
        selection = json.loads((ROOT / "dotfiles/opencode/cli.json").read_text())
        self.assertEqual(selection["theme"], {"name": "ember-grove", "mode": "dark"})

    def test_installer_preserves_cli_settings(self):
        installer = (ROOT / "setup_environment.sh").read_text()
        block = re.search(
            r'python3 - "\$DOTFILES_DIR/dotfiles/opencode/cli.json"[^\n]*<<\'PY\'\n(.*?)\nPY',
            installer,
            re.S,
        )
        self.assertIsNotNone(block)
        with tempfile.TemporaryDirectory(dir=SCRATCH) as folder:
            target = Path(folder) / "cli.json"
            original = {"plugins": ["./local-plugin"], "session": {"sidebar": "hide"}, "theme": {"name": "matrix"}}
            target.write_text(json.dumps(original))
            command = [sys.executable, "-c", block[1], str(ROOT / "dotfiles/opencode/cli.json"), str(target)]
            subprocess.run(command, check=True)
            updated = json.loads(target.read_text())
            self.assertEqual(updated["plugins"], original["plugins"])
            self.assertEqual(updated["session"], original["session"])
            self.assertEqual(updated["theme"]["name"], "ember-grove")
            self.assertEqual(len(list(Path(folder).glob("cli.json.backup.*"))), 1)
            subprocess.run(command, check=True)
            self.assertEqual(len(list(Path(folder).glob("cli.json.backup.*"))), 1, "merge should be idempotent")


@unittest.skipUnless(shutil.which("starship") and shutil.which("git"), "requires Starship and Git")
class StarshipTests(unittest.TestCase):
    def test_prompt_states(self):
        config = ROOT / "dotfiles/starship.toml"
        with config.open("rb") as file:
            tomllib.load(file)
        env = dict(os.environ, STARSHIP_CONFIG=str(config), STARSHIP_SHELL="zsh", TERM="xterm-256color")

        def prompt(path, *flags):
            result = subprocess.run(
                ["starship", "prompt", "--path", str(path), "--logical-path", str(path), *flags],
                cwd=path, env=env, capture_output=True, text=True, check=True,
            )
            self.assertFalse(result.stderr.strip(), result.stderr)
            self.assertNotIn("\x1b[48;", result.stdout, "no solid background blocks")
            plain = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout).replace("%{", "").replace("%}", "")
            if "--continuation" not in flags:
                self.assertTrue(plain.startswith("\n│ "), repr(plain))
                self.assertEqual(len(plain.splitlines()), 3)
                self.assertRegex(plain.splitlines()[1], r"— \d{2}:\d{2}$")
            return plain

        with tempfile.TemporaryDirectory(dir=SCRATCH) as folder:
            path = Path(folder)
            self.assertNotIn("", prompt(path), "non-Git prompts should omit branch")
            subprocess.run(["git", "init", "-q", "-b", "main", folder], check=True)
            git = ["git", "-C", folder]
            tracked = path / "tracked.txt"
            tracked.write_text("original\n")
            subprocess.run([*git, "add", "tracked.txt"], check=True)
            subprocess.run([*git, "-c", "user.name=Prompt Test", "-c", "user.email=test@example.invalid",
                            "commit", "-qm", "fixture"], check=True)
            self.assertNotIn("[!]", prompt(path))
            tracked.write_text("changed\n")
            (path / "untracked.txt").write_text("untracked\n")
            self.assertIn("[!?]", prompt(path))
            subprocess.run([*git, "add", "tracked.txt"], check=True)
            self.assertIn("[+?]", prompt(path))
            self.assertTrue(prompt(path, "--status", "1").endswith("│ ✗ "))
            self.assertTrue(prompt(path, "--keymap", "vicmd").endswith("│ ❮ "))
            self.assertEqual(prompt(path, "--continuation"), "│ · ")
            subprocess.run([*git, "checkout", "--detach", "-q"], check=True)
            self.assertRegex(prompt(path), r"@[0-9a-f]{7}")


if __name__ == "__main__":
    unittest.main()
